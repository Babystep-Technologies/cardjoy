# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::AdjustOrganizationCredits, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:organization) { create(:organization, created_by: user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation AdjustOrganizationCredits($organizationId: ID!, $amount: Int!, $reason: String!) {
        adjustOrganizationCredits(input: { organizationId: $organizationId, amount: $amount, reason: $reason }) {
          organization {
            id
            creditBalance
            credits { amount reason note }
          }
          errors
        }
      }
    GRAPHQL
  end

  def exec(amount: 10, reason: "Chargeback reversal per ticket #42", organization_id: organization.id, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { organizationId: organization_id, amount: amount, reason: reason } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  before { create(:organization_credit, organization: organization, amount: 20, reason: "purchase") }

  it "records a positive correction and returns the updated balance" do
    payload = exec(amount: 10).dig("data", "adjustOrganizationCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("organization", "creditBalance")).to eq 30
    expect(payload.dig("organization", "credits").first).to eq(
      "amount" => 10, "reason" => "admin_adjustment", "note" => "Chargeback reversal per ticket #42"
    )
  end

  it "records a negative correction" do
    payload = exec(amount: -5).dig("data", "adjustOrganizationCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("organization", "creditBalance")).to eq 15
  end

  it "writes the reason onto the event's audit trail" do
    exec(amount: 10, reason: "Goodwill for a delayed order")

    row = organization.organization_credits.order(:created_at).last
    expect(row.reason).to eq "admin_adjustment"
    expect(row.note).to eq "Goodwill for a delayed order"
    expect(row.events.first["event_data"]).to include(
      "organization_id" => organization.id,
      "adjusted_by_admin_id" => admin.id,
      "amount" => 10,
      "note" => "Goodwill for a delayed order"
    )
  end

  it "refuses to overdraw the pool and changes nothing" do
    payload = exec(amount: -25).dig("data", "adjustOrganizationCredits")

    expect(payload["organization"]).to be_nil
    expect(payload["errors"]).to eq [ "Not enough credits in the pool" ]
    expect(organization.credit_balance).to eq 20
  end

  it "rejects a zero amount" do
    payload = exec(amount: 0).dig("data", "adjustOrganizationCredits")

    expect(payload["errors"]).to eq [ "Amount must not be zero" ]
  end

  it "requires a reason" do
    payload = exec(reason: "").dig("data", "adjustOrganizationCredits")

    expect(payload["errors"]).to eq [ "Reason is required" ]
    expect(organization.organization_credits.count).to eq 1
  end

  it "reports an unknown organization as not found" do
    payload = exec(organization_id: "0").dig("data", "adjustOrganizationCredits")

    expect(payload["errors"]).to eq [ "Organization not found" ]
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "adjustOrganizationCredits")).to be_nil
    expect(organization.credit_balance).to eq 20
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
    expect(organization.credit_balance).to eq 20
  end
end
