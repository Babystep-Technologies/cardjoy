# scripts/test_stripe_webhook.rb
# bin/rails runner script/test_stripe_webhook.rb

require "net/http"
require "uri"
require "json"
require "openssl"

# === Configuration ===
WEBHOOK_SECRET = Rails.application.credentials.dig(:stripe, :webhook_secret)
RAILS_WEBHOOK_URL = "http://localhost:3000/webhooks/stripe" # change port if needed

raise "No user exists, please create a user first" if User.count.zero?
USER_ID = User.first.id # 🔧 Replace with a valid user ID in your dev DB
AMOUNT_TOTAL = 800 # $8 = 5 credits

# === Mock event payload ===

event_data = {
  id: "evt_test_webhook",
  object: "event",
  type: "checkout.session.completed",
  data: {
    object: {
      id: "cs_test_123456",
      object: "checkout.session",
      amount_total: AMOUNT_TOTAL,
      metadata: {
        user_id: USER_ID
      }
    }
  }
}

payload_json = JSON.generate(event_data)

# === Stripe signature header ===

timestamp = Time.now.to_i
signed_payload = "#{timestamp}.#{payload_json}"
signature = OpenSSL::HMAC.hexdigest("SHA256", WEBHOOK_SECRET, signed_payload)
signature_header = "t=#{timestamp},v1=#{signature}"

# === Send the webhook request ===

uri = URI.parse(RAILS_WEBHOOK_URL)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = uri.scheme == "https"
request = Net::HTTP::Post.new(uri.request_uri)
request["Content-Type"] = "application/json"
request["Stripe-Signature"] = signature_header
request.body = payload_json

puts "Sending test webhook to #{RAILS_WEBHOOK_URL}..."

response = http.request(request)

puts "\n== Webhook Response =="
puts "Status: #{response.code} #{response.message}"
puts response.body
