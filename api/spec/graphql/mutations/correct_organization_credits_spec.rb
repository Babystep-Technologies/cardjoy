# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::CorrectOrganizationCredits, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:organization) { create(:organization, created_by: user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation CorrectOrganizationCredits($organizationId: ID!, $amount: Int!, $reason: String!) {
        correctOrganizationCredits(input: { organizationId: $organizationId, amount: $amount, reason: $reason }) {
          organization {
            id
            creditBalance
            credits { amount reason actor { id } adminActorName }
          }
          errors
        }
      }
    GRAPHQL
  end

  def exec(amount: -10, reason: "mis-keyed grant", organization_id: organization.id, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { organizationId: organization_id, amount: amount, reason: reason } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "appends a negative row and returns the corrected balance" do
    create(:organization_credit, organization: organization, amount: 30, reason: "purchase")

    payload = exec(amount: -10).dig("data", "correctOrganizationCredits")
    row = payload.dig("organization", "credits").first

    expect(payload["errors"]).to be_empty
    expect(payload.dig("organization", "creditBalance")).to eq 20
    expect(row["amount"]).to eq(-10)
    expect(row["reason"]).to eq "mis-keyed grant"
  end

  it "names the acting admin instead of leaving the actor blank" do
    payload = exec(amount: -10).dig("data", "correctOrganizationCredits")
    row = payload.dig("organization", "credits").first

    expect(row["actor"]).to be_nil
    expect(row["adminActorName"]).to eq admin.name
  end

  it "records the correction with its event kind and the acting admin" do
    exec(amount: -10)

    row = organization.organization_credits.order(:created_at).last
    expect(row.events.first).to include("event_kind" => "admin_correction")
    expect(row.events.first["event_data"]).to include(
      "organization_id" => organization.id,
      "corrected_by_admin_id" => admin.id,
      "amount" => -10
    )
  end

  it "rejects a zero or positive amount, leaving grantOrganizationCredits as the only path in" do
    payload = exec(amount: 10).dig("data", "correctOrganizationCredits")

    expect(payload["errors"]).to eq [ "Amount must be negative" ]
    expect(organization.organization_credits).to be_empty
  end

  it "requires a reason" do
    payload = exec(reason: "").dig("data", "correctOrganizationCredits")

    expect(payload["errors"]).to eq [ "Reason is required" ]
    expect(organization.organization_credits).to be_empty
  end

  it "reports an unknown organization as not found" do
    payload = exec(organization_id: "0").dig("data", "correctOrganizationCredits")

    expect(payload["errors"]).to eq [ "Organization not found" ]
  end

  it "refuses a regular user's token outright" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(organization.organization_credits).to be_empty
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
    expect(organization.organization_credits).to be_empty
  end
end
