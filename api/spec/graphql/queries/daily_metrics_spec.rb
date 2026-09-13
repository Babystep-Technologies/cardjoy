# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Queries::DailyMetrics, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      query DailyMetrics($days: Int) {
        dailyMetrics(days: $days) {
          date
          users
          cards
          invitations
          rsvps
        }
      }
    GRAPHQL
  end

  def exec(days: :omitted)
    variables = days == :omitted ? {} : { days: days }
    post "/graphql", params: { query: query, variables: variables }.to_json, headers: headers
    JSON.parse(response.body)
  end

  around do |example|
    travel_to(Time.utc(2026, 6, 15, 12, 0, 0)) { example.run }
  end

  it "defaults to a trailing 30-day series" do
    json = exec
    expect(json.dig("data", "dailyMetrics").length).to eq 31 # 30 days back through today, inclusive
  end

  it "rejects a days value beyond MAX_DAYS instead of building an unbounded range" do
    json = exec(days: 100_000)

    expect(json.dig("data", "dailyMetrics")).to be_nil
    expect(json["errors"].first["message"]).to eq("days must be between 1 and #{Queries::DailyMetrics::MAX_DAYS}")
  end

  it "rejects zero and negative values" do
    json = exec(days: 0)
    expect(json["errors"].first["message"]).to include("must be between 1 and")
  end

  it "accepts the maximum allowed value" do
    json = exec(days: Queries::DailyMetrics::MAX_DAYS)
    expect(json.dig("data", "dailyMetrics").length).to eq(Queries::DailyMetrics::MAX_DAYS + 1)
  end
end
