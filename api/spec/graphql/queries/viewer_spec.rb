require "rails_helper"

RSpec.describe "Viewer", type: :request do
  let(:user) { create(:user, name: "Ada Lovelace", email: "ada@example.com") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      query Viewer {
        viewer {
          id
          name
          email
          creditBalance
          activeOrganization { id name slug }
          organizationMemberships { id role organization { id name slug } }
        }
      }
    GRAPHQL
  end

  def exec
    post "/graphql", params: { query: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "viewer")
  end

  it "returns the caller's identity and credit balance" do
    result = exec

    expect(result).to include(
      "id" => user.id.to_s,
      "name" => "Ada Lovelace",
      "email" => "ada@example.com",
      "creditBalance" => User::SIGNUP_CREDIT_GRANT
    )
  end

  it "returns every membership with its role and organization" do
    admin_org = create(:organization, name: "Acme Corp")
    member_org = create(:organization, name: "Globex")
    create(:organization_membership, :admin, organization: admin_org, user:)
    create(:organization_membership, organization: member_org, user:)

    memberships = exec["organizationMemberships"]

    expect(memberships.map { |m| [ m.dig("organization", "name"), m["role"] ] })
      .to contain_exactly([ "Acme Corp", "admin" ], [ "Globex", "member" ])
  end

  it "does not leak another user's memberships" do
    create(:organization_membership, organization: create(:organization), user: create(:user))

    expect(exec["organizationMemberships"]).to be_empty
  end

  it "returns a null active organization for a Personal context" do
    expect(exec["activeOrganization"]).to be_nil
  end

  it "returns the active organization once one is set" do
    organization = create(:organization, name: "Acme Corp")
    create(:organization_membership, organization:, user:)
    user.update!(active_organization: organization)

    expect(exec["activeOrganization"]).to include("name" => "Acme Corp", "slug" => "acme-corp")
  end

  it "omits memberships in archived organizations" do
    organization = create(:organization, name: "Acme Corp")
    create(:organization_membership, :admin, organization:, user:)
    organization.archive!

    expect(exec["organizationMemberships"]).to be_empty
  end

  it "rejects unauthenticated callers" do
    post "/graphql", params: { query: }.to_json, headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
