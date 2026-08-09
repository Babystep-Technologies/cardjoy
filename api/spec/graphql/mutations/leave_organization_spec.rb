require "rails_helper"

RSpec.describe Mutations::LeaveOrganization, type: :request do
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
      mutation LeaveOrganization($organizationId: ID!) {
        leaveOrganization(input: { organizationId: $organizationId }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def exec(organization_id, user: member)
    post "/graphql",
      params: { query:, variables: { organizationId: organization_id } }.to_json,
      headers: headers_for(user)
    JSON.parse(response.body).dig("data", "leaveOrganization")
  end

  it "lets a member leave" do
    membership

    data = exec(organization.id)

    expect(data["success"]).to be(true)
    expect(data["errors"]).to be_empty
    expect(OrganizationMembership.exists?(membership.id)).to be(false)
  end

  it "lets an admin leave while another admin remains" do
    other = create(:user)
    other_membership = create(:organization_membership, :admin, organization:, user: other)

    expect(exec(organization.id, user: other)["success"]).to be(true)
    expect(OrganizationMembership.exists?(other_membership.id)).to be(false)
  end

  it "clears the leaver's active organization" do
    membership
    member.update!(active_organization: organization)

    exec(organization.id)

    expect(member.reload.active_organization_id).to be_nil
  end

  it "only removes the caller's own membership" do
    membership
    exec(organization.id)

    expect(OrganizationMembership.exists?(organization.membership_for(admin).id)).to be(true)
  end

  it "refuses to let the last remaining admin leave and changes nothing" do
    data = exec(organization.id, user: admin)

    expect(data["success"]).to be(false)
    expect(data["errors"]).to eq([ OrganizationMembership::LAST_ADMIN_ERROR ])
    expect(OrganizationMembership.exists?(organization.membership_for(admin).id)).to be(true)
  end

  it "returns Not authorized for a non-member" do
    data = exec(organization.id, user: create(:user))

    expect(data["success"]).to be(false)
    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "returns Not authorized for an unknown organization" do
    expect(exec("0")["errors"]).to eq([ "Not authorized" ])
  end

  it "returns Not authorized once the organization is archived" do
    membership
    organization.archive!

    expect(exec(organization.id)["errors"]).to eq([ "Not authorized" ])
    expect(OrganizationMembership.exists?(membership.id)).to be(true)
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
