# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::AdjustUserCredits, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user, :without_signup_credits) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation AdjustUserCredits($userId: ID!, $amount: Int!, $reason: String!) {
        adjustUserCredits(input: { userId: $userId, amount: $amount, reason: $reason }) {
          user { id creditBalance }
          errors
        }
      }
    GRAPHQL
  end

  def exec(amount: 3, reason: "double-charged, refunding", user_id: user.id, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { userId: user_id, amount: amount, reason: reason } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "grants a positive adjustment and returns the updated balance" do
    payload = exec(amount: 3).dig("data", "adjustUserCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("user", "creditBalance")).to eq 3

    row = user.credits.order(:created_at).last
    expect(row.reason).to eq "double-charged, refunding"
    expect(row.events.first).to include("event_kind" => "admin_grant")
    expect(row.events.first["event_data"]).to include("admin_id" => admin.id, "amount" => 3)
  end

  it "records a negative correction as admin_correction" do
    create(:credit, user: user, amount: 5, reason: "promotion")

    payload = exec(amount: -2, reason: "mis-keyed promo").dig("data", "adjustUserCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("user", "creditBalance")).to eq 3
    expect(user.credits.order(:created_at).last.events.first).to include("event_kind" => "admin_correction")
  end

  it "refuses to drive the balance below zero" do
    create(:credit, user: user, amount: 2, reason: "promotion")

    payload = exec(amount: -5, reason: "oops").dig("data", "adjustUserCredits")

    expect(payload["errors"]).to eq [ "Amount would drive balance below zero" ]
    expect(user.reload.credit_balance).to eq 2
  end

  it "requires a reason" do
    payload = exec(reason: "").dig("data", "adjustUserCredits")

    expect(payload["errors"]).to eq [ "Reason is required" ]
    expect(user.credits.reload).to be_empty
  end

  it "reports an unknown user as not found" do
    payload = exec(user_id: "0").dig("data", "adjustUserCredits")

    expect(payload["errors"]).to eq [ "User not found" ]
  end

  it "refuses a regular user's token outright" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "adjustUserCredits")).to be_nil
    expect(user.credits.reload).to be_empty
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
    expect(user.credits.reload).to be_empty
  end
end
