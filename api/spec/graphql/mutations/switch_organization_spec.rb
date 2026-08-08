require "rails_helper"

RSpec.describe Mutations::SwitchOrganization, type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def headers_for(caller)
    token = JWT.encode({ user_id: caller.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation SwitchOrganization($organizationId: ID) {
        switchOrganization(input: { organizationId: $organizationId }) {
          user { id activeOrganization { id name } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, caller: user)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(caller)
    JSON.parse(response.body).dig("data", "switchOrganization")
  end

  it "sets the active organization for a member" do
    create(:organization_membership, organization:, user:)

    data = exec({ organizationId: organization.id })

    expect(data["errors"]).to be_empty
    expect(data.dig("user", "activeOrganization")).to include("name" => "Acme Corp")
    expect(user.reload.active_organization_id).to eq(organization.id)
  end

  it "clears the active organization back to Personal when passed null" do
    create(:organization_membership, organization:, user:)
    user.update!(active_organization: organization)

    data = exec({ organizationId: nil })

    expect(data["errors"]).to be_empty
    expect(data.dig("user", "activeOrganization")).to be_nil
    expect(user.reload.active_organization_id).to be_nil
  end

  it "switches directly between two organizations" do
    other = create(:organization, name: "Globex")
    create(:organization_membership, organization:, user:)
    create(:organization_membership, organization: other, user:)
    user.update!(active_organization: organization)

    data = exec({ organizationId: other.id })

    expect(data.dig("user", "activeOrganization")).to include("name" => "Globex")
    expect(user.reload.active_organization_id).to eq(other.id)
  end

  it "returns Not authorized for an organization the caller does not belong to" do
    create(:organization_membership, organization: create(:organization), user:)
    outsider_org = create(:organization, name: "Initech")

    data = exec({ organizationId: outsider_org.id })

    expect(data["user"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "leaves the existing active organization untouched when refused" do
    create(:organization_membership, organization:, user:)
    user.update!(active_organization: organization)

    exec({ organizationId: create(:organization).id })

    expect(user.reload.active_organization_id).to eq(organization.id)
  end

  it "returns Not authorized for an unknown organization" do
    data = exec({ organizationId: "0" })

    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "returns Not authorized for an archived organization the caller belongs to" do
    create(:organization_membership, :admin, organization:, user:)
    organization.archive!

    data = exec({ organizationId: organization.id })

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(user.reload.active_organization_id).to be_nil
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
