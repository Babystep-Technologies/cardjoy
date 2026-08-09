require "rails_helper"

RSpec.describe Mutations::AcceptOrganizationInvitation, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }
  let(:invitee) { create(:user, email: "invitee@example.com") }
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
      mutation AcceptOrganizationInvitation($token: String!) {
        acceptOrganizationInvitation(input: { token: $token }) {
          membership { id role user { id } }
          organization { id name }
          errors
        }
      }
    GRAPHQL
  end

  def exec(token, user: invitee)
    post "/graphql", params: { query:, variables: { token: } }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "acceptOrganizationInvitation")
  end

  it "creates the membership for an existing user" do
    data = nil
    expect { data = exec(invitation.token) }.to change(OrganizationMembership, :count).by(1)

    expect(data["errors"]).to be_empty
    expect(data.dig("membership", "role")).to eq("member")
    expect(data.dig("membership", "user", "id")).to eq(invitee.id.to_s)
    expect(data["organization"]).to include("name" => "Acme Corp")
    expect(organization.reload.users).to include(invitee)
  end

  it "closes the invitation out" do
    exec(invitation.token)

    expect(invitation.reload.status).to eq(OrganizationInvitation::ACCEPTED)
    expect(invitation.accepted_at).to be_present
  end

  it "grants the invited role" do
    admin_invite = create(:organization_invitation, :admin, organization:, invited_by: admin,
                                                            email: "boss@example.com")
    boss = create(:user, email: "boss@example.com")

    data = exec(admin_invite.token, user: boss)

    expect(data.dig("membership", "role")).to eq("admin")
  end

  # The invite may be sent long before the recipient has an account; signing up
  # first and then opening the link is the normal path, not an edge case.
  it "works for someone who signed up after being invited" do
    late_invite = create(:organization_invitation, organization:, invited_by: admin,
                                                   email: "newcomer@example.com")
    newcomer = create(:user, email: "newcomer@example.com")

    data = exec(late_invite.token, user: newcomer)

    expect(data["errors"]).to be_empty
    expect(organization.reload.users).to include(newcomer)
  end

  it "matches the invited email case-insensitively" do
    shouty = create(:user, email: "Loud@Example.com")
    shouty_invite = create(:organization_invitation, organization:, invited_by: admin,
                                                     email: "loud@example.com")

    expect(exec(shouty_invite.token, user: shouty)["errors"]).to be_empty
  end

  it "refuses a user signed in as a different email and leaves the invitation pending" do
    other = create(:user, email: "someone-else@example.com")

    data = nil
    expect { data = exec(invitation.token, user: other) }.not_to change(OrganizationMembership, :count)

    expect(data["membership"]).to be_nil
    expect(data["errors"]).to eq([ OrganizationInvitation::WRONG_EMAIL_ERROR ])
    expect(invitation.reload.status).to eq(OrganizationInvitation::PENDING)
  end

  it "refuses an expired invitation" do
    expired = create(:organization_invitation, :expired, organization:, invited_by: admin,
                                                         email: invitee.email)

    data = nil
    expect { data = exec(expired.token) }.not_to change(OrganizationMembership, :count)
    expect(data["errors"]).to eq([ OrganizationInvitation::EXPIRED_ERROR ])
  end

  it "refuses a revoked invitation" do
    revoked = create(:organization_invitation, :revoked, organization:, invited_by: admin,
                                                         email: invitee.email)

    data = nil
    expect { data = exec(revoked.token) }.not_to change(OrganizationMembership, :count)
    expect(data["errors"]).to eq([ OrganizationInvitation::REVOKED_ERROR ])
  end

  it "refuses an invitation that was already accepted, so the token is single-use" do
    exec(invitation.token)

    data = nil
    expect { data = exec(invitation.token) }.not_to change(OrganizationMembership, :count)
    expect(data["errors"]).to eq([ OrganizationInvitation::ALREADY_ACCEPTED_ERROR ])
  end

  it "refuses an invitation to an archived organization" do
    organization.archive!

    data = exec(invitation.token)
    expect(data["errors"]).to eq([ OrganizationInvitation::EXPIRED_ERROR ])
  end

  it "returns a not-found error for an unknown token" do
    data = exec("no-such-token")
    expect(data["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
  end

  it "is a no-op for someone who is already a member" do
    create(:organization_membership, organization:, user: invitee)

    data = nil
    expect { data = exec(invitation.token) }.not_to change(OrganizationMembership, :count)

    expect(data["errors"]).to be_empty
    expect(invitation.reload.status).to eq(OrganizationInvitation::ACCEPTED)
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { token: invitation.token } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
