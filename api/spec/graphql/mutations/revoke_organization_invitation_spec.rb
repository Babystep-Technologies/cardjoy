require "rails_helper"

RSpec.describe Mutations::RevokeOrganizationInvitation, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, created_by: admin) }
  let(:invitation) do
    create(:organization_invitation, organization:, invited_by: admin, email: "invitee@example.com")
  end
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation RevokeOrganizationInvitation($id: ID!) {
        revokeOrganizationInvitation(input: { id: $id }) {
          invitation { id status }
          errors
        }
      }
    GRAPHQL
  end

  def exec(id, user: admin)
    post "/graphql", params: { query:, variables: { id: } }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "revokeOrganizationInvitation")
  end

  it "lets an admin revoke a pending invitation" do
    data = exec(invitation.id)

    expect(data["errors"]).to be_empty
    expect(data.dig("invitation", "status")).to eq("revoked")
    expect(invitation.reload.status).to eq(OrganizationInvitation::REVOKED)
  end

  it "stops the token working" do
    exec(invitation.id)
    expect(invitation.reload).not_to be_usable
  end

  it "refuses to revoke an invitation that was already accepted" do
    accepted = create(:organization_invitation, :accepted, organization:, invited_by: admin,
                                                           email: "joined@example.com")

    data = exec(accepted.id)

    expect(data["errors"]).to eq([ described_class::NOT_PENDING_ERROR ])
    expect(accepted.reload.status).to eq(OrganizationInvitation::ACCEPTED)
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = exec(invitation.id, user: member)

    expect(data["invitation"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(invitation.reload.status).to eq(OrganizationInvitation::PENDING)
  end

  it "returns Not authorized for a non-member" do
    data = exec(invitation.id, user: create(:user))

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(invitation.reload.status).to eq(OrganizationInvitation::PENDING)
  end

  it "returns Not authorized for an admin of a different organization" do
    other_admin = create(:user)
    other = create(:organization, created_by: other_admin)
    create(:organization_membership, :admin, organization: other, user: other_admin)

    expect(exec(invitation.id, user: other_admin)["errors"]).to eq([ "Not authorized" ])
  end

  it "returns Not authorized once the organization is archived" do
    organization.archive!
    expect(exec(invitation.id)["errors"]).to eq([ "Not authorized" ])
  end

  it "returns a not-found error for an unknown invitation" do
    expect(exec("0")["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { id: invitation.id } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
