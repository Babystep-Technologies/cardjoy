require "rails_helper"

RSpec.describe Mutations::DeleteOrganization, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation DeleteOrganization($organizationId: ID!) {
        deleteOrganization(input: { organizationId: $organizationId }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, user: admin)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "deleteOrganization")
  end

  it "soft-deletes the organization" do
    data = exec({ organizationId: organization.id })

    expect(data).to include("success" => true, "errors" => [])
    expect(Organization.find_by(id: organization.id)).to be_nil
    expect(Organization.unscoped.find(organization.id).deleted_at).to be_present
  end

  it "keeps memberships so the organization stays restorable" do
    expect { exec({ organizationId: organization.id }) }
      .not_to change(OrganizationMembership, :count)
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = exec({ organizationId: organization.id }, user: member)

    expect(data).to include("success" => false, "errors" => [ "Not authorized" ])
    expect(Organization.find_by(id: organization.id)).to be_present
  end

  it "returns Not authorized for a non-member" do
    data = exec({ organizationId: organization.id }, user: create(:user))

    expect(data).to include("success" => false, "errors" => [ "Not authorized" ])
    expect(Organization.find_by(id: organization.id)).to be_present
  end

  it "returns a not-found error for an unknown organization" do
    data = exec({ organizationId: "0" })
    expect(data).to include("success" => false, "errors" => [ "Organization not found" ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
