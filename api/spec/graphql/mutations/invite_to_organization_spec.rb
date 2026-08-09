require "rails_helper"

RSpec.describe Mutations::InviteToOrganization, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation InviteToOrganization($organizationId: ID!, $emails: [String!]!, $role: String) {
        inviteToOrganization(input: { organizationId: $organizationId, emails: $emails, role: $role }) {
          invitations { id email role status expiresAt organization { name } invitedBy { id } }
          skippedEmails
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, user: admin)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "inviteToOrganization")
  end

  it "invites an email that has no CardJoy account" do
    expect {
      data = exec({ organizationId: organization.id, emails: [ "newcomer@example.com" ] })

      expect(data["errors"]).to be_empty
      expect(data["skippedEmails"]).to be_empty
      expect(data["invitations"].first).to include(
        "email" => "newcomer@example.com",
        "role" => "member",
        "status" => "pending"
      )
      expect(data["invitations"].first["organization"]).to eq("name" => "Acme Corp")
    }.to change(OrganizationInvitation, :count).by(1)

    expect(User.find_by(email: "newcomer@example.com")).to be_nil
  end

  it "records who sent the invitation" do
    data = exec({ organizationId: organization.id, emails: [ "newcomer@example.com" ] })
    expect(data.dig("invitations", 0, "invitedBy", "id")).to eq(admin.id.to_s)
  end

  it "invites at the requested role" do
    data = exec({ organizationId: organization.id, emails: [ "boss@example.com" ], role: "admin" })
    expect(data.dig("invitations", 0, "role")).to eq("admin")
  end

  it "downcases and dedupes the addresses it is given" do
    data = exec({ organizationId: organization.id, emails: [ "Same@Example.com", "same@example.com" ] })

    expect(data["errors"]).to be_empty
    expect(data["invitations"].map { |i| i["email"] }).to eq([ "same@example.com" ])
  end

  it "emails each new invitee a join link" do
    expect {
      exec({ organizationId: organization.id, emails: [ "a@example.com", "b@example.com" ] })
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob).twice
  end

  it "skips an email that already has a pending invitation, without erroring on the batch" do
    create(:organization_invitation, organization:, email: "pending@example.com")

    data = nil
    expect {
      data = exec({ organizationId: organization.id, emails: [ "pending@example.com", "fresh@example.com" ] })
    }.to change(OrganizationInvitation, :count).by(1)

    expect(data["errors"]).to be_empty
    expect(data["skippedEmails"]).to eq([ "pending@example.com" ])
    expect(data["invitations"].map { |i| i["email"] }).to eq([ "fresh@example.com" ])
  end

  it "skips an email that already belongs to a member" do
    member = create(:user, email: "member@example.com")
    create(:organization_membership, organization:, user: member)

    data = nil
    expect {
      data = exec({ organizationId: organization.id, emails: [ "Member@example.com" ] })
    }.not_to change(OrganizationInvitation, :count)

    expect(data["errors"]).to be_empty
    expect(data["skippedEmails"]).to eq([ "member@example.com" ])
  end

  it "re-invites an email whose earlier invitation was revoked" do
    create(:organization_invitation, :revoked, organization:, email: "second-chance@example.com")

    data = exec({ organizationId: organization.id, emails: [ "second-chance@example.com" ] })

    expect(data["errors"]).to be_empty
    expect(data["invitations"].map { |i| i["email"] }).to eq([ "second-chance@example.com" ])
  end

  it "reports a malformed address and still invites the rest" do
    data = exec({ organizationId: organization.id, emails: [ "nope", "yes@example.com" ] })

    expect(data["errors"]).to eq([ "nope: Email is invalid" ])
    expect(data["invitations"].map { |i| i["email"] }).to eq([ "yes@example.com" ])
  end

  it "rejects a role outside admin | member" do
    data = nil
    expect {
      data = exec({ organizationId: organization.id, emails: [ "a@example.com" ], role: "owner" })
    }.not_to change(OrganizationInvitation, :count)

    expect(data["errors"]).to eq([ OrganizationMembership::INVALID_ROLE_ERROR ])
  end

  it "rejects an empty list of addresses" do
    data = exec({ organizationId: organization.id, emails: [ "  " ] })
    expect(data["errors"]).to eq([ described_class::NO_EMAILS_ERROR ])
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = nil
    expect {
      data = exec({ organizationId: organization.id, emails: [ "a@example.com" ] }, user: member)
    }.not_to change(OrganizationInvitation, :count)

    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "returns Not authorized for a non-member" do
    data = exec({ organizationId: organization.id, emails: [ "a@example.com" ] }, user: create(:user))
    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "returns a not-found error for an unknown organization" do
    data = exec({ organizationId: "0", emails: [ "a@example.com" ] })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "returns a not-found error for an archived organization" do
    organization.archive!
    data = exec({ organizationId: organization.id, emails: [ "a@example.com" ] })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id, emails: [ "a@example.com" ] } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
