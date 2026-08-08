require "rails_helper"

RSpec.describe Mutations::CreateOrganization, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateOrganization($name: String!, $description: String) {
        createOrganization(input: { name: $name, description: $description }) {
          organization { id name slug description membersCount }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "createOrganization")
  end

  it "creates the organization and makes the caller an admin" do
    expect { exec({ name: "Acme Corp", description: "We send cards" }) }
      .to change(Organization, :count).by(1)
      .and change(OrganizationMembership, :count).by(1)

    data = JSON.parse(response.body).dig("data", "createOrganization")
    expect(data["errors"]).to be_empty
    expect(data["organization"]).to include(
      "name" => "Acme Corp",
      "slug" => "acme-corp",
      "description" => "We send cards",
      "membersCount" => 1
    )

    organization = Organization.find(data.dig("organization", "id"))
    expect(organization.created_by).to eq(user)
    expect(organization.membership_for(user)).to be_admin
  end

  it "lets one user create several organizations" do
    exec({ name: "Acme Corp" })
    exec({ name: "Bookclub" })

    expect(user.organizations.count).to eq(2)
  end

  it "rolls back the organization when the membership cannot be created" do
    allow_any_instance_of(Organization)
      .to receive(:organization_memberships)
      .and_raise(ActiveRecord::RecordInvalid.new(OrganizationMembership.new))

    expect { exec({ name: "Acme Corp" }) }.not_to change(Organization, :count)
  end

  it "returns validation errors for a blank name" do
    data = exec({ name: "" })
    expect(data["organization"]).to be_nil
    expect(data["errors"]).to include("Name can't be blank")
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { name: "Acme Corp" } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
