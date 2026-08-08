require "rails_helper"

RSpec.describe Queries::OrganizationInvitationPreview, type: :request do
  let(:inviter) { create(:user, name: "Dana Host") }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: inviter) }
  let(:invitation) do
    create(:organization_invitation, organization:, invited_by: inviter, email: "invitee@example.com")
  end

  let(:query) do
    <<~GRAPHQL
      query OrganizationInvitationPreview($token: String!) {
        organizationInvitationPreview(token: $token) {
          organizationName
          invitedByName
          valid
        }
      }
    GRAPHQL
  end

  # No Authorization header anywhere in this spec: the whole point of the
  # preview is that it renders before the recipient has an account.
  def exec(token)
    post "/graphql",
      params: { query:, variables: { token: }, operationName: "OrganizationInvitationPreview" }.to_json,
      headers: { "Content-Type" => "application/json" }
    JSON.parse(response.body).dig("data", "organizationInvitationPreview")
  end

  it "describes a live invitation to a signed-out visitor" do
    data = exec(invitation.token)

    expect(response).to have_http_status(:ok)
    expect(data).to eq(
      "organizationName" => "Acme Corp",
      "invitedByName" => "Dana Host",
      "valid" => true
    )
  end

  it "exposes nothing beyond the organization name, inviter name, and validity" do
    exec(invitation.token)

    body = response.body
    expect(body).not_to include(invitation.email)
    expect(body).not_to include(invitation.token)
    expect(body).not_to include(inviter.email)
  end

  it "rejects a request for the invited email" do
    post "/graphql",
      params: {
        query: "query OrganizationInvitationPreview($token: String!) { " \
               "organizationInvitationPreview(token: $token) { email } }",
        variables: { token: invitation.token },
        operationName: "OrganizationInvitationPreview"
      }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(JSON.parse(response.body)["errors"].first["message"])
      .to include("Field 'email' doesn't exist")
  end

  it "still names the organization for an expired invitation, marked invalid" do
    expired = create(:organization_invitation, :expired, organization:, invited_by: inviter)

    expect(exec(expired.token)).to include("organizationName" => "Acme Corp", "valid" => false)
  end

  it "marks a revoked invitation invalid" do
    revoked = create(:organization_invitation, :revoked, organization:, invited_by: inviter)
    expect(exec(revoked.token)).to include("valid" => false)
  end

  it "marks an accepted invitation invalid" do
    accepted = create(:organization_invitation, :accepted, organization:, invited_by: inviter)
    expect(exec(accepted.token)).to include("valid" => false)
  end

  it "returns null for an unknown token" do
    expect(exec("no-such-token")).to be_nil
  end

  it "returns null once the organization is archived" do
    token = invitation.token
    organization.archive!

    expect(exec(token)).to be_nil
  end
end
