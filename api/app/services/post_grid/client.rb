# typed: true
# frozen_string_literal: true

module PostGrid
  # A thin, typed HTTP client for PostGrid.
  #
  # Deliberately not a gem. The surface we need is a handful of endpoints, and
  # the parts that actually matter here — which errors are retryable, that a
  # create carries a caller-supplied Idempotency-Key, that nothing logs an
  # address — are exactly the parts a third-party wrapper would decide for us.
  #
  # Net::HTTP is the same choice Oauth::SlackController makes; no new dependency.
  #
  # ## Logging
  #
  # Never log a request or response body. Bodies here contain home addresses on
  # the way out and API keys in the failure paths, and this application's logs
  # are not a place either belongs. We log the method, the path, the HTTP
  # status, and PostGrid's object id — enough to trace a card through support
  # without leaking where anyone lives.
  class Client
    extend T::Sig

    # Print & Mail. Address verification is a separate product on a separate
    # base path, hence `ADDRESS_VERIFICATION_BASE_URL` — same key, same header.
    BASE_URL = "https://api.postgrid.com/print-mail/v1"
    ADDRESS_VERIFICATION_BASE_URL = "https://api.postgrid.com/v1/addver"

    # A hung PostGrid call must never hold a Puma thread. These are wall-clock
    # seconds per attempt, not per call: MAX_ATTEMPTS multiplies them.
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    # Bounded, and bounded low. A GraphQL request is waiting on this, so the
    # worst case is 3 × (5 + 15) + backoff. Beyond that the honest answer to
    # the user is "try again", not a spinner.
    MAX_ATTEMPTS = 3
    # Exponential: 0.5s, then 1s. Jittered so a PostGrid blip doesn't turn
    # every one of our threads into a synchronised thundering herd.
    BACKOFF_BASE = 0.5
    MAX_BACKOFF = 5.0

    sig { returns(Symbol) }
    attr_reader :mode

    sig { params(mode: Symbol, base_url: String).void }
    def initialize(mode: PostGrid.default_mode, base_url: BASE_URL)
      @mode = mode
      @base_url = base_url
    end

    # A non-mutating read.
    sig { params(path: String, params: T::Hash[T.untyped, T.untyped]).returns(T::Hash[String, T.untyped]) }
    def get(path, params: {})
      request(Net::HTTP::Get, path, params:)
    end

    # A POST that creates something billable at PostGrid.
    #
    # `idempotency_key` is required and caller-supplied — this class must not
    # invent one, because the whole point is that a retry *of the same logical
    # order* reuses the key. A key generated in here would be fresh on every
    # attempt and would happily mail the same postcard twice.
    sig do
      params(path: String, body: T::Hash[T.untyped, T.untyped], idempotency_key: String)
        .returns(T::Hash[String, T.untyped])
    end
    def create(path, body:, idempotency_key:)
      raise ArgumentError, "idempotency_key is required for PostGrid creates" if idempotency_key.blank?

      request(Net::HTTP::Post, path, body:, idempotency_key:)
    end

    # A POST that creates nothing — address verification is the case. No
    # Idempotency-Key, because there is no duplicate to guard against.
    sig { params(path: String, body: T::Hash[T.untyped, T.untyped]).returns(T::Hash[String, T.untyped]) }
    def post(path, body:)
      request(Net::HTTP::Post, path, body:)
    end

    private

    sig { returns(String) }
    def api_key
      key = PostGrid.api_key(mode: @mode)
      raise ConfigurationError, "No PostGrid API key configured for mode #{@mode}" if key.blank?

      key
    end

    def request(verb_class, path, params: {}, body: nil, idempotency_key: nil)
      uri = build_uri(path, params)
      attempt = 0

      begin
        attempt += 1
        perform(verb_class, uri, body:, idempotency_key:)
      rescue Error => e
        raise unless e.retryable? && attempt < MAX_ATTEMPTS

        sleep(backoff_for(attempt))
        retry
      end
    end

    def perform(verb_class, uri, body:, idempotency_key:)
      request = verb_class.new(uri)
      request["x-api-key"] = api_key
      request["Accept"] = "application/json"
      # PostGrid accepts JSON bodies on the endpoints we use.
      if body
        request["Content-Type"] = "application/json"
        request.body = body.to_json
      end
      request["Idempotency-Key"] = idempotency_key if idempotency_key.present?

      response = execute(request, uri)
      handle(response, uri)
    end

    # Every transport-level failure collapses to ServiceError: from a caller's
    # point of view "PostGrid didn't answer" and "PostGrid answered 503" call
    # for the same decision. Timeout is listed explicitly because the default
    # Net::HTTP behaviour without it is to hang forever.
    def execute(request, uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.request(request)
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => e
      raise ServiceError.new("PostGrid request timed out: #{e.class}")
    rescue SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError => e
      raise ServiceError.new("PostGrid connection failed: #{e.class}")
    end

    def handle(response, uri)
      status = response.code.to_i
      payload = parse(response.body)

      log(uri, status, payload)

      return payload if status.between?(200, 299)

      raise error_for(status, payload)
    end

    # PostGrid reports errors as `{"error": {"message": …, "type": …}}`, but a
    # 502 from something in front of it is HTML. Both have to end up as the
    # right exception class, so the *status* decides the class and the body only
    # supplies detail.
    def error_for(status, payload)
      message = payload.dig("error", "message").presence || "PostGrid request failed with status #{status}"
      code = payload.dig("error", "type").presence

      case status
      when 401, 403 then AuthenticationError.new(message, status:, error_code: code)
      when 429      then RateLimitError.new(message, status:, error_code: code)
      when 400..499 then InvalidRequestError.new(message, status:, error_code: code)
      else               ServiceError.new(message, status:, error_code: code)
      end
    end

    def parse(body)
      return {} if body.blank?

      parsed = JSON.parse(body)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      # A non-JSON body is a proxy error page. Swallow it rather than logging
      # it: the status already carries the signal, and the body might not.
      {}
    end

    # Path, status, and PostGrid's object id. Nothing else — see the class note.
    def log(uri, status, payload)
      object_id = payload.dig("data", "id") || payload["id"]
      Rails.logger.info(
        "[PostGrid] #{uri.path} status=#{status} mode=#{@mode}#{" id=#{object_id}" if object_id.present?}"
      )
    end

    def build_uri(path, params)
      uri = URI.parse("#{@base_url}#{path}")
      uri.query = params.to_query if params.present?
      uri
    end

    # Full jitter: sleep anywhere in [0, exponential]. Retrying at a precise
    # 0.5s means every thread that failed together retries together.
    def backoff_for(attempt)
      ceiling = [ BACKOFF_BASE * (2**(attempt - 1)), MAX_BACKOFF ].min
      Kernel.rand * ceiling
    end
  end
end
