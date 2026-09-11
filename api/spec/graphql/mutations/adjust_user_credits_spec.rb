# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::AdjustUserCredits, type: :request do
  let(:admin) { create(:admin) }
  let(:target) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def target_token = JWT.encode({ user_id: target.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation AdjustUserCredits($userId: ID!, $amount: Int!, $reason: String!) {
        adjustUserCredits(input: { userId: $userId, amount: $amount, reason: $reason }) {
          user {
            id
            creditBalance
            credits { amount reason note }
          }
          errors
        }
      }
    GRAPHQL
  end

  def exec(amount: 10, reason: "Compensation for a failed print run", user_id: target.id, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { userId: user_id, amount: amount, reason: reason } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "grants credits and returns the updated balance" do
    starting_balance = target.credit_balance

    payload = exec(amount: 10).dig("data", "adjustUserCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("user", "creditBalance")).to eq starting_balance + 10
    expect(payload.dig("user", "credits").first).to eq(
      "amount" => 10, "reason" => "admin_adjustment", "note" => "Compensation for a failed print run"
    )
  end

  it "deducts credits with a negative amount" do
    starting_balance = target.credit_balance

    payload = exec(amount: -2).dig("data", "adjustUserCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("user", "creditBalance")).to eq starting_balance - 2
  end

  it "writes the reason onto the event's audit trail" do
    exec(amount: 10, reason: "Goodwill for a delayed order")

    row = target.credits.order(:created_at).last
    expect(row.reason).to eq "admin_adjustment"
    expect(row.note).to eq "Goodwill for a delayed order"
    expect(row.events.first["event_data"]).to include(
      "user_id" => target.id,
      "adjusted_by_admin_id" => admin.id,
      "amount" => 10,
      "note" => "Goodwill for a delayed order"
    )
  end

  it "refuses to overdraw the balance and changes nothing" do
    starting_balance = target.credit_balance

    payload = exec(amount: -(starting_balance + 1)).dig("data", "adjustUserCredits")

    expect(payload["user"]).to be_nil
    expect(payload["errors"]).to eq [ "Not enough credits" ]
    expect(target.credit_balance).to eq starting_balance
  end

  it "rejects a zero amount" do
    payload = exec(amount: 0).dig("data", "adjustUserCredits")

    expect(payload["errors"]).to eq [ "Amount must not be zero" ]
  end

  it "requires a reason" do
    starting_count = target.credits.count

    payload = exec(reason: "").dig("data", "adjustUserCredits")

    expect(payload["errors"]).to eq [ "Reason is required" ]
    expect(target.credits.count).to eq starting_count
  end

  it "reports an unknown user as not found" do
    payload = exec(user_id: "0").dig("data", "adjustUserCredits")

    expect(payload["errors"]).to eq [ "User not found" ]
  end

  it "refuses a regular user's token outright rather than returning a partial result, even the target's own" do
    body = exec(token: target_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "adjustUserCredits")).to be_nil
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
