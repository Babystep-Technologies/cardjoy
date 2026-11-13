class Rack::Attack
  # Throttle requests to /card/:id by IP: 60 requests/minute
  throttle("req/ip/card_view", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.match?(/^\/card\/[\w-]+$/) && req.get?
  end

  # A registry passcode is short, so slow down guessing: 20 GraphQL calls that carry a passcode per
  # minute per IP (legitimate use is a handful).
  throttle("req/ip/registry_passcode", limit: 20, period: 1.minute) do |req|
    next unless req.post? && req.path == "/graphql"

    body = req.body.read(65_536).to_s
    req.body.rewind
    req.ip if body.match?(/"passcode"\s*:\s*"/)
  end

  # Block common bots
  # blocklist("block bad bots") do |req|
  #   req.user_agent =~ /curl|python|libwww-perl|scrapy|bot/i
  # end

  # Log blocked requests
  self.throttled_responder = lambda do |request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Too many requests" }.to_json ]
    ]
  end
end
