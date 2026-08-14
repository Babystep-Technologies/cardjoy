require "rails_helper"

# The roster and pending-invitation fields on OrganizationType, which back the
# members page (#127). Read through `viewer`, the way the client reaches them.
RSpec.describe "Organization roster", type: :request do
  let(:admin) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:member) { create(:user, name: "Sam Member", email: "sam@example.com") }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:query) do
    <<~GRAPHQL
      query Viewer {
        viewer {
          activeOrganization {
            memberships { id role user { id name email } }
            pendingInvitations { id email role invitedBy { name } }
          }
        }
      }
    GRAPHQL
  end

  def exec(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    post "/graphql",
      params: { query: }.to_json,
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    JSON.parse(response.body).dig("data", "viewer", "activeOrganization")
  end

  before do
    create(:organization_membership, :admin, organization:, user: admin)
    create(:organization_membership, organization:, user: member)
    admin.update!(active_organization: organization)
    member.update!(active_organization: organization)
  end

  it "returns every member with their role, oldest first" do
    roster = exec(admin)["memberships"]

    expect(roster.map { |m| [ m.dig("user", "name"), m["role"] ] })
      .to eq([ [ "Dana Host", "admin" ], [ "Sam Member", "member" ] ])
  end

  it "shows a plain member the same roster" do
    expect(exec(member)["memberships"].map { |m| m.dig("user", "email") })
      .to contain_exactly("dana@example.com", "sam@example.com")
  end

  it "returns outstanding invitations to an admin" do
    create(:organization_invitation, organization:, invited_by: admin, email: "new@example.com")

    invitations = exec(admin)["pendingInvitations"]

    expect(invitations.length).to eq(1)
    expect(invitations.first).to include(
      "email" => "new@example.com",
      "role" => "member",
      "invitedBy" => { "name" => "Dana Host" }
    )
  end

  it "leaves out invitations that are no longer pending" do
    create(:organization_invitation, :revoked, organization:, invited_by: admin)
    create(:organization_invitation, :accepted, organization:, invited_by: admin)
    live = create(:organization_invitation, organization:, invited_by: admin)

    expect(exec(admin)["pendingInvitations"].map { |i| i["id"] }).to eq([ live.id.to_s ])
  end

  # A member can see who else is here; who an admin has approached is not yet
  # the membership list, and the invited email is not theirs to read.
  it "hides pending invitations from a plain member" do
    create(:organization_invitation, organization:, invited_by: admin, email: "new@example.com")

    expect(exec(member)["pendingInvitations"]).to be_empty
  end

  # Nothing in the product hands an OrganizationType to a non-member today, so
  # this writes the column past User's validation to reach the guard. It is
  # there so the roster never becomes readable if some later payload does.
  it "returns nothing to someone who does not belong to the organization" do
    outsider = create(:user)
    User.where(id: outsider.id).update_all(active_organization_id: organization.id)

    expect(exec(outsider)).to eq("memberships" => [], "pendingInvitations" => [])
  end
end
