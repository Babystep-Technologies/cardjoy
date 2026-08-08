require "rails_helper"

RSpec.describe Mutations::UpdateOrganization, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation UpdateOrganization($organizationId: ID!, $name: String, $description: String) {
        updateOrganization(input: { organizationId: $organizationId, name: $name, description: $description }) {
          organization { id name slug description }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, user: admin)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "updateOrganization")
  end

  it "lets an admin rename the organization" do
    data = exec({ organizationId: organization.id, name: "Acme Incorporated" })

    expect(data["errors"]).to be_empty
    expect(data["organization"]).to include("name" => "Acme Incorporated")
    expect(organization.reload.name).to eq("Acme Incorporated")
  end

  it "keeps the slug stable across a rename" do
    data = exec({ organizationId: organization.id, name: "Acme Incorporated" })
    expect(data.dig("organization", "slug")).to eq("acme-corp")
  end

  it "updates the description on its own" do
    data = exec({ organizationId: organization.id, description: "Now with more cards" })

    expect(data["errors"]).to be_empty
    expect(data["organization"]).to include("name" => "Acme Corp", "description" => "Now with more cards")
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = exec({ organizationId: organization.id, name: "Hijacked" }, user: member)

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(organization.reload.name).to eq("Acme Corp")
  end

  it "returns Not authorized for a non-member" do
    data = exec({ organizationId: organization.id, name: "Hijacked" }, user: create(:user))

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "returns a not-found error for an unknown organization" do
    data = exec({ organizationId: "0", name: "Ghost" })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "returns a not-found error for an archived organization" do
    organization.archive!
    data = exec({ organizationId: organization.id, name: "Ghost" })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "returns validation errors for a blank name" do
    data = exec({ organizationId: organization.id, name: "" })

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to include("Name can't be blank")
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id, name: "Ghost" } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
