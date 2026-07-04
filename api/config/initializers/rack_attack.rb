class Rack::Attack
  # Throttle requests to /card/:id by IP: 60 requests/minute
  throttle("req/ip/card_view", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.match?(/^\/card\/[\w-]+$/) && req.get?
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
