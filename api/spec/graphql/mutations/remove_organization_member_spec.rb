require "rails_helper"

RSpec.describe Mutations::RemoveOrganizationMember, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, created_by: admin) }
  let(:member) { create(:user) }
  let(:membership) { create(:organization_membership, organization:, user: member) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation RemoveOrganizationMember($id: ID!) {
        removeOrganizationMember(input: { id: $id }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def exec(id, user: admin)
    post "/graphql", params: { query:, variables: { id: } }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "removeOrganizationMember")
  end

  it "lets an admin remove a member" do
    data = exec(membership.id)

    expect(data["success"]).to be(true)
    expect(data["errors"]).to be_empty
    expect(OrganizationMembership.exists?(membership.id)).to be(false)
  end

  it "lets an admin remove another admin while one remains" do
    other = create(:organization_membership, :admin, organization:, user: create(:user))

    expect(exec(other.id)["success"]).to be(true)
    expect(OrganizationMembership.exists?(other.id)).to be(false)
  end

  it "clears the removed member's active organization" do
    membership
    member.update!(active_organization: organization)

    exec(membership.id)

    expect(member.reload.active_organization_id).to be_nil
  end

  it "cuts the removed member off from the organization" do
    membership
    member.update!(active_organization: organization)
    exec(membership.id)

    # Nothing they can do with the organization now: they can't switch back to it.
    switch = <<~GRAPHQL
      mutation SwitchOrganization($organizationId: ID) {
        switchOrganization(input: { organizationId: $organizationId }) { user { id } errors }
      }
    GRAPHQL
    post "/graphql",
      params: { query: switch, variables: { organizationId: organization.id } }.to_json,
      headers: headers_for(member)

    expect(JSON.parse(response.body).dig("data", "switchOrganization", "errors")).to eq([ "Not authorized" ])
  end

  it "refuses to remove the last remaining admin and changes nothing" do
    admin_membership = organization.membership_for(admin)

    data = exec(admin_membership.id)

    expect(data["success"]).to be(false)
    expect(data["errors"]).to eq([ OrganizationMembership::LAST_ADMIN_ERROR ])
    expect(OrganizationMembership.exists?(admin_membership.id)).to be(true)
  end

  it "returns Not authorized for a member who is not an admin" do
    other = create(:organization_membership, organization:, user: create(:user))

    data = exec(other.id, user: member)

    expect(data["success"]).to be(false)
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(OrganizationMembership.exists?(other.id)).to be(true)
  end

  it "returns Not authorized for a non-member" do
    data = exec(membership.id, user: create(:user))

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(OrganizationMembership.exists?(membership.id)).to be(true)
  end

  it "returns Not authorized for an admin of a different organization" do
    other_admin = create(:user)
    other = create(:organization, created_by: other_admin)
    create(:organization_membership, :admin, organization: other, user: other_admin)

    expect(exec(membership.id, user: other_admin)["errors"]).to eq([ "Not authorized" ])
    expect(OrganizationMembership.exists?(membership.id)).to be(true)
  end

  it "returns Not authorized once the organization is archived" do
    membership
    organization.archive!

    expect(exec(membership.id)["errors"]).to eq([ "Not authorized" ])
    expect(OrganizationMembership.exists?(membership.id)).to be(true)
  end

  it "returns a not-found error for an unknown membership" do
    expect(exec("0")["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { id: membership.id } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
