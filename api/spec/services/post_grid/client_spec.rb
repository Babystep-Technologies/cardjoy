require "rails_helper"

RSpec.describe PostGrid::Client do
  subject(:client) { described_class.new(mode: :test) }

  let(:url) { "#{described_class::BASE_URL}/postcards" }

  before do
    with_post_grid_key
    # The retry tests would otherwise spend real seconds sleeping.
    allow(client).to receive(:sleep)
  end

  describe "authentication" do
    it "sends the mode's key in the x-api-key header" do
      request = stub_request(:get, url).to_return(status: 200, body: "{}")

      client.get("/postcards")

      expect(request.with(headers: { "x-api-key" => PostGridHelpers::TEST_API_KEY })).to have_been_made
    end

    it "raises ConfigurationError rather than calling out with no key" do
      with_post_grid_key(test_key: nil)
      allow(Rails.application.credentials).to receive(:dig).with(:post_grid, :test_api_key).and_return(nil)

      expect { client.get("/postcards") }.to raise_error(PostGrid::ConfigurationError)
    end
  end

  describe "idempotency" do
    it "sends the caller's Idempotency-Key on a create" do
      request = stub_request(:post, url).to_return(status: 200, body: '{"id":"postcard_1"}')

      client.create("/postcards", body: { size: "6x4" }, idempotency_key: "order-42")

      expect(request.with(headers: { "Idempotency-Key" => "order-42" })).to have_been_made
    end

    # The client must never mint its own key: a fresh key on each retry would
    # cheerfully mail the same postcard twice.
    it "refuses a create with no key rather than inventing one" do
      expect { client.create("/postcards", body: {}, idempotency_key: "") }
        .to raise_error(ArgumentError, /idempotency_key is required/)
    end

    it "omits the header on a non-creating post" do
      request = stub_request(:post, url).to_return(status: 200, body: "{}")

      client.post("/postcards", body: {})

      expect(request.with { |req| !req.headers.key?("Idempotency-Key") }).to have_been_made
    end
  end

  describe "error mapping" do
    {
      401 => PostGrid::AuthenticationError,
      403 => PostGrid::AuthenticationError,
      400 => PostGrid::InvalidRequestError,
      404 => PostGrid::InvalidRequestError,
      422 => PostGrid::InvalidRequestError,
      429 => PostGrid::RateLimitError,
      500 => PostGrid::ServiceError,
      503 => PostGrid::ServiceError
    }.each do |status, error_class|
      it "maps #{status} to #{error_class}" do
        stub_request(:get, url).to_return(status:, body: '{"error":{"message":"nope","type":"some_error"}}')

        expect { client.get("/postcards") }.to raise_error(error_class) do |error|
          expect(error.status).to eq(status)
          expect(error.error_code).to eq("some_error")
        end
      end
    end

    it "surfaces PostGrid's message" do
      stub_request(:get, url).to_return(status: 401, body: post_grid_fixture("error_unauthorized"))

      expect { client.get("/postcards") }.to raise_error(PostGrid::AuthenticationError, /invalid or has been revoked/)
    end

    # A 502 from a proxy in front of PostGrid is an HTML page, not JSON. The
    # status has to decide the class regardless.
    it "still maps a non-JSON error body by status" do
      stub_request(:get, url).to_return(status: 502, body: "<html>Bad Gateway</html>")

      expect { client.get("/postcards") }.to raise_error(PostGrid::ServiceError, /status 502/)
    end
  end

  describe "retries" do
    it "retries a 500 with backoff up to the bounded limit, then raises" do
      stub_request(:get, url).to_return(status: 500, body: post_grid_fixture("error_server"))

      expect { client.get("/postcards") }.to raise_error(PostGrid::ServiceError)

      expect(a_request(:get, url)).to have_been_made.times(described_class::MAX_ATTEMPTS)
      expect(client).to have_received(:sleep).twice
    end

    it "retries a 429" do
      stub_request(:get, url).to_return(status: 429, body: "{}")

      expect { client.get("/postcards") }.to raise_error(PostGrid::RateLimitError)
      expect(a_request(:get, url)).to have_been_made.times(described_class::MAX_ATTEMPTS)
    end

    it "returns the payload as soon as a retry succeeds" do
      stub_request(:get, url)
        .to_return(status: 503, body: "{}")
        .then.to_return(status: 200, body: '{"id":"postcard_1"}')

      expect(client.get("/postcards")).to eq("id" => "postcard_1")
      expect(a_request(:get, url)).to have_been_made.twice
    end

    # The load-bearing half: a 4xx is our bug or the user's input. Replaying it
    # fails identically and just burns the user's time.
    it "does not retry a 4xx" do
      stub_request(:get, url).to_return(status: 400, body: post_grid_fixture("error_invalid_request"))

      expect { client.get("/postcards") }.to raise_error(PostGrid::InvalidRequestError)
      expect(a_request(:get, url)).to have_been_made.once
    end

    it "does not retry an auth failure" do
      stub_request(:get, url).to_return(status: 401, body: post_grid_fixture("error_unauthorized"))

      expect { client.get("/postcards") }.to raise_error(PostGrid::AuthenticationError)
      expect(a_request(:get, url)).to have_been_made.once
    end
  end

  describe "timeouts" do
    it "raises ServiceError on a read timeout rather than hanging" do
      stub_request(:get, url).to_timeout

      expect { client.get("/postcards") }.to raise_error(PostGrid::ServiceError, /timed out|connection failed/i)
    end

    it "retries a timeout, since the request may never have landed" do
      stub_request(:get, url).to_timeout.then.to_return(status: 200, body: '{"id":"postcard_1"}')

      expect(client.get("/postcards")).to eq("id" => "postcard_1")
    end

    it "raises ServiceError when the connection is refused" do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED)

      expect { client.get("/postcards") }.to raise_error(PostGrid::ServiceError, /connection failed/)
    end

    it "sets explicit connect and read timeouts on the connection" do
      stub_request(:get, url).to_return(status: 200, body: "{}")
      http = instance_spy(Net::HTTP, request: instance_double(Net::HTTPResponse, code: "200", body: "{}"))
      allow(Net::HTTP).to receive(:new).and_return(http)

      client.get("/postcards")

      expect(http).to have_received(:open_timeout=).with(described_class::OPEN_TIMEOUT)
      expect(http).to have_received(:read_timeout=).with(described_class::READ_TIMEOUT)
    end
  end

  describe "logging" do
    let(:log) { StringIO.new }

    before { allow(Rails).to receive(:logger).and_return(ActiveSupport::Logger.new(log)) }

    it "logs the path, status, and PostGrid object id" do
      stub_request(:post, url).to_return(status: 200, body: '{"id":"postcard_abc"}')

      client.create("/postcards", body: { size: "6x4" }, idempotency_key: "order-42")

      expect(log.string).to include("/print-mail/v1/postcards", "status=200", "id=postcard_abc")
    end

    # The one that matters. A key in the logs is a key in every log sink,
    # backup, and support screenshot downstream of them.
    it "never logs the API key or an address" do
      stub_request(:post, url).to_return(status: 200, body: '{"id":"postcard_abc"}')

      client.create(
        "/postcards",
        body: { to: { addressLine1: "123 Market St", city: "San Francisco" } },
        idempotency_key: "order-42"
      )

      expect(log.string).not_to include(PostGridHelpers::TEST_API_KEY)
      expect(log.string).not_to include("test_sk_")
      expect(log.string).not_to include("123 Market St")
    end

    it "does not leak the key when PostGrid rejects it" do
      stub_request(:get, url).to_return(status: 401, body: post_grid_fixture("error_unauthorized"))

      expect { client.get("/postcards") }.to raise_error(PostGrid::AuthenticationError)
      expect(log.string).not_to include(PostGridHelpers::TEST_API_KEY)
    end
  end
end
