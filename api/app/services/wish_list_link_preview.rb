# typed: true
# frozen_string_literal: true

require "resolv"
require "ipaddr"

# Fetches OpenGraph/meta data for a wish list item's pasted URL so the host gets a title/image/price
# preview instead of typing everything by hand. See issue #95, "Gift items -- universal paste-a-link +
# recognized brands". Recognized-brand styling (logos, per-store treatment) is explicitly Phase 2
# (#96) and not attempted here -- this only extracts generic OG/meta tags.
#
# The URL comes from a signed-in host, but it still points wherever they paste it, so every fetch is
# treated as attacker-controlled: only http(s) is allowed, every hostname -- and every redirect target
# -- is resolved and checked against loopback/private/link-local ranges before we connect, redirects
# are capped, and the response body is read with a hard size limit. Any failure anywhere (blocked
# host, timeout, non-2xx, unparsable HTML) degrades to no preview rather than raising: the host can
# always fall back to typing the item in by hand, and adding a manual item must never be blocked by
# this.
class WishListLinkPreview
  extend T::Sig

  OPEN_TIMEOUT = 4
  READ_TIMEOUT = 6
  MAX_REDIRECTS = 3
  MAX_BODY_BYTES = 2 * 1024 * 1024
  USER_AGENT = "CardJoyLinkPreview/1.0 (+https://cardjoy.app)"
  ZERO_NETWORK = IPAddr.new("0.0.0.0/8")

  Result = Struct.new(:title, :image_url, :price, :store, keyword_init: true)
  FetchedResponse = Struct.new(:redirect, :location, :success, :content_type, :body, keyword_init: true)

  sig { params(url: String).returns(T.nilable(Result)) }
  def self.fetch(url)
    new.fetch(url)
  end

  sig { params(url: String).returns(T.nilable(Result)) }
  def fetch(url)
    html, final_uri = fetch_html(url, MAX_REDIRECTS)
    return nil if html.blank? || final_uri.nil?

    parse(html, final_uri)
  rescue StandardError => e
    Rails.logger.warn("WishListLinkPreview: failed to fetch #{url}: #{e.class}: #{e.message}")
    nil
  end

  private

  def fetch_html(url, redirects_left)
    uri = safe_uri(url)
    return [ nil, nil ] unless uri

    response = request(uri)
    return [ nil, nil ] unless response

    if response.redirect
      return [ nil, nil ] if redirects_left <= 0 || response.location.blank?

      return fetch_html(URI.join(uri, response.location).to_s, redirects_left - 1)
    end

    return [ nil, nil ] unless response.success
    return [ nil, nil ] unless response.content_type.blank? || response.content_type.include?("html")

    [ response.body, uri ]
  end

  # Streams the body so a hostile server can't force us to buffer an unbounded response; `break`
  # inside `read_body`'s block stops reading from the socket as soon as the cap is hit.
  def request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = USER_AGENT
    req["Accept"] = "text/html,application/xhtml+xml"

    result = T.let(nil, T.nilable(WishListLinkPreview::FetchedResponse))
    http.start do |conn|
      conn.request(req) do |response|
        result =
          if response.is_a?(Net::HTTPRedirection)
            FetchedResponse.new(redirect: true, location: response["location"])
          elsif response.is_a?(Net::HTTPSuccess)
            FetchedResponse.new(success: true, content_type: response["content-type"].to_s, body: capped_body(response))
          else
            FetchedResponse.new(success: false)
          end
      end
    end
    result
  end

  def capped_body(response)
    buffer = +""
    response.read_body do |chunk|
      buffer << chunk
      break if buffer.bytesize >= MAX_BODY_BYTES
    end
    buffer.byteslice(0, MAX_BODY_BYTES)
  end

  # Only an http(s) URL whose host (and every redirect hop) resolves exclusively to public IPs is
  # safe to fetch. "localhost" is rejected by name since it commonly bypasses DNS entirely.
  def safe_uri(raw_url)
    uri = URI.parse(raw_url)
    return nil unless uri.is_a?(URI::HTTP) && uri.host.present?
    return nil unless safe_host?(uri.host)

    uri
  rescue URI::InvalidURIError
    nil
  end

  def safe_host?(host)
    return false if host.blank?
    return false if host.casecmp("localhost").zero?

    addresses = resolve_addresses(host)
    addresses.present? && addresses.none? { |ip| blocked_ip?(ip) }
  end

  def resolve_addresses(host)
    literal = parse_ip(host)
    return [ literal ] if literal

    Resolv.getaddresses(host).filter_map { |address| parse_ip(address) }
  rescue Resolv::ResolvError, SocketError
    []
  end

  def parse_ip(str)
    IPAddr.new(str)
  rescue IPAddr::Error
    nil
  end

  def blocked_ip?(ip)
    ip = ip.native if ip.ipv4_mapped?
    ip.loopback? || ip.private? || ip.link_local? || ZERO_NETWORK.include?(ip)
  end

  def parse(html, uri)
    doc = Nokogiri::HTML(html)

    title = meta_content(doc, "og:title").presence || doc.at_css("title")&.text&.strip.presence
    return nil if title.blank?

    Result.new(
      title: title,
      image_url: absolute_url(meta_content(doc, "og:image"), uri),
      price: meta_content(doc, "product:price:amount").presence || meta_content(doc, "og:price:amount"),
      store: meta_content(doc, "og:site_name").presence || uri.host&.sub(/\Awww\./, "")
    )
  end

  def meta_content(doc, property)
    doc.at_css("meta[property='#{property}']")&.attr("content")&.strip.presence
  end

  def absolute_url(value, base_uri)
    return nil if value.blank?

    URI.join(base_uri, value).to_s
  rescue URI::InvalidURIError
    nil
  end
end
