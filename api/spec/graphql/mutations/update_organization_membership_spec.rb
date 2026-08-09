require "rails_helper"

RSpec.describe Mutations::UpdateOrganizationMembership, type: :request do
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
      mutation UpdateOrganizationMembership($id: ID!, $role: String!) {
        updateOrganizationMembership(input: { id: $id, role: $role }) {
          membership { id role user { id } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(id, role, user: admin)
    post "/graphql", params: { query:, variables: { id:, role: } }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "updateOrganizationMembership")
  end

  it "promotes a member to admin" do
    data = exec(membership.id, OrganizationMembership::ADMIN)

    expect(data["errors"]).to be_empty
    expect(data.dig("membership", "role")).to eq(OrganizationMembership::ADMIN)
    expect(membership.reload.role).to eq(OrganizationMembership::ADMIN)
  end

  it "lets the newly promoted admin perform admin actions" do
    exec(membership.id, OrganizationMembership::ADMIN)

    # The promoted member can now demote the admin who promoted them.
    data = exec(organization.membership_for(admin).id, OrganizationMembership::MEMBER, user: member)

    expect(data["errors"]).to be_empty
    expect(organization.membership_for(admin).role).to eq(OrganizationMembership::MEMBER)
  end

  it "demotes another admin to member" do
    other = create(:organization_membership, :admin, organization:, user: create(:user))

    data = exec(other.id, OrganizationMembership::MEMBER)

    expect(data["errors"]).to be_empty
    expect(other.reload.role).to eq(OrganizationMembership::MEMBER)
  end

  it "refuses to demote the last remaining admin and changes nothing" do
    data = exec(organization.membership_for(admin).id, OrganizationMembership::MEMBER)

    expect(data["membership"]).to be_nil
    expect(data["errors"]).to eq([ OrganizationMembership::LAST_ADMIN_ERROR ])
    expect(organization.membership_for(admin).role).to eq(OrganizationMembership::ADMIN)
  end

  it "rejects a role outside admin | member" do
    data = exec(membership.id, "owner")

    expect(data["errors"]).to eq([ OrganizationMembership::INVALID_ROLE_ERROR ])
    expect(membership.reload.role).to eq(OrganizationMembership::MEMBER)
  end

  it "returns Not authorized for a member who is not an admin" do
    other = create(:organization_membership, organization:, user: create(:user))

    data = exec(other.id, OrganizationMembership::ADMIN, user: member)

    expect(data["membership"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(other.reload.role).to eq(OrganizationMembership::MEMBER)
  end

  it "returns Not authorized when a member tries to promote themselves" do
    data = exec(membership.id, OrganizationMembership::ADMIN, user: member)

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(membership.reload.role).to eq(OrganizationMembership::MEMBER)
  end

  it "returns Not authorized for a non-member" do
    data = exec(membership.id, OrganizationMembership::ADMIN, user: create(:user))

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(membership.reload.role).to eq(OrganizationMembership::MEMBER)
  end

  it "returns Not authorized for an admin of a different organization" do
    other_admin = create(:user)
    other = create(:organization, created_by: other_admin)
    create(:organization_membership, :admin, organization: other, user: other_admin)

    expect(exec(membership.id, OrganizationMembership::ADMIN, user: other_admin)["errors"])
      .to eq([ "Not authorized" ])
    expect(membership.reload.role).to eq(OrganizationMembership::MEMBER)
  end

  it "returns Not authorized once the organization is archived" do
    membership
    organization.archive!

    expect(exec(membership.id, OrganizationMembership::ADMIN)["errors"]).to eq([ "Not authorized" ])
  end

  it "returns a not-found error for an unknown membership" do
    expect(exec("0", OrganizationMembership::ADMIN)["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { id: membership.id, role: OrganizationMembership::ADMIN } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
