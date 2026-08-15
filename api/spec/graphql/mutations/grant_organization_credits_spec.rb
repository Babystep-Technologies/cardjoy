# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::GrantOrganizationCredits, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:organization) { create(:organization, created_by: user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation GrantOrganizationCredits($organizationId: ID!, $amount: Int!) {
        grantOrganizationCredits(input: { organizationId: $organizationId, amount: $amount }) {
          organization {
            id
            creditBalance
            credits { amount reason }
          }
          errors
        }
      }
    GRAPHQL
  end

  def exec(amount: 25, organization_id: organization.id, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { organizationId: organization_id, amount: amount } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "adds the credits to the pool and returns the updated balance" do
    create(:organization_credit, organization: organization, amount: 5, reason: "purchase")

    payload = exec(amount: 25).dig("data", "grantOrganizationCredits")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("organization", "creditBalance")).to eq 30
    expect(payload.dig("organization", "credits").first).to eq("amount" => 25, "reason" => "admin_grant")
  end

  it "records the grant on the ledger with its own reason and event kind" do
    expect { exec(amount: 25) }.to change { organization.organization_credits.count }.by(1)

    row = organization.organization_credits.order(:created_at).last
    expect(row.amount).to eq 25
    expect(row.reason).to eq "admin_grant"
    expect(row.events.first).to include("event_kind" => "admin_grant")
    expect(row.events.first["event_data"]).to include(
      "organization_id" => organization.id,
      "granted_by_admin_id" => admin.id,
      "amount" => 25
    )
  end

  it "rejects a zero or negative amount rather than draining the pool" do
    payload = exec(amount: -5).dig("data", "grantOrganizationCredits")

    expect(payload["errors"]).to eq [ "Amount must be positive" ]
    expect(organization.organization_credits).to be_empty
  end

  it "reports an unknown organization as not found" do
    payload = exec(organization_id: "0").dig("data", "grantOrganizationCredits")

    expect(payload["errors"]).to eq [ "Organization not found" ]
  end

  # Archived organizations are outside Organization's default scope, so they
  # read as not-found here just as they do in the list and detail queries.
  it "refuses to grant into an archived organization" do
    organization.archive!

    payload = exec.dig("data", "grantOrganizationCredits")

    expect(payload["errors"]).to eq [ "Organization not found" ]
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "grantOrganizationCredits")).to be_nil
    expect(organization.organization_credits).to be_empty
  end

  # Even for a user who administers the organization in the product: granting
  # credits is an internal action, not one a customer can take on themselves.
  it "refuses an organization's own admin" do
    create(:organization_membership, :admin, organization: organization, user: user)

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
