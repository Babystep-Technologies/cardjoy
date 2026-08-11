require "rails_helper"

RSpec.describe "organization-scoped invitations", type: :request do
  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:org_admin) { create(:user) }
  let(:stranger) { create(:user) }
  let(:organization) { create(:organization) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before do
    create(:organization_membership, organization:, user: owner)
    create(:organization_membership, organization:, user: member)
    create(:organization_membership, :admin, organization:, user: org_admin)
  end

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  def exec(query, variables, user:, key:)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", key)
  end

  describe "CreateInvitation" do
    let(:query) do
      <<~GRAPHQL
        mutation CreateInvitation($title: String!, $eventDate: ISO8601Date!, $eventTime: String!, $organizationId: ID) {
          createInvitation(input: {
            title: $title, eventDate: $eventDate, eventTime: $eventTime, organizationId: $organizationId
          }) {
            invitation { title organization { id } }
            errors
          }
        }
      GRAPHQL
    end

    def create_invitation(user:, organization_id: nil)
      exec(query,
           { title: "Offsite", eventDate: (Date.today + 30).iso8601, eventTime: "18:00", organizationId: organization_id },
           user:, key: "createInvitation")
    end

    it "creates an invitation owned by the organization" do
      data = create_invitation(user: owner, organization_id: organization.id)

      expect(data["errors"]).to be_empty
      expect(data.dig("invitation", "organization", "id")).to eq(organization.id.to_s)
      expect(Invitation.last.organization_id).to eq(organization.id)
    end

    it "refuses an organization the caller does not belong to, and spends no credit" do
      balance = stranger.credit_balance

      data = create_invitation(user: stranger, organization_id: organization.id)

      expect(data["invitation"]).to be_nil
      expect(data["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
      expect(stranger.reload.credit_balance).to eq(balance)
      expect(Invitation.count).to eq(0)
    end

    it "still creates a personal invitation when no organization is given" do
      data = create_invitation(user: owner)

      expect(data["errors"]).to be_empty
      expect(Invitation.last.organization_id).to be_nil
    end
  end

  describe "UpdateInvitation" do
    let!(:invitation) { create(:invitation, user: owner, organization:, title: "Old") }

    let(:query) do
      <<~GRAPHQL
        mutation UpdateInvitation($externalId: String!, $title: String) {
          updateInvitation(input: { externalId: $externalId, title: $title }) {
            invitation { title }
            errors
          }
        }
      GRAPHQL
    end

    def update(user:)
      exec(query, { externalId: invitation.external_id, title: "New" }, user:, key: "updateInvitation")
    end

    it "lets an organization admin edit a colleague's invitation" do
      expect(update(user: org_admin)["errors"]).to be_empty
      expect(invitation.reload.title).to eq("New")
    end

    it "refuses an ordinary member" do
      expect(update(user: member)["errors"]).to eq([ "Invitation not found" ])
      expect(invitation.reload.title).to eq("Old")
    end

    it "refuses a non-member" do
      expect(update(user: stranger)["errors"]).to eq([ "Invitation not found" ])
    end

    # Regression: a personal invitation is still editable by its owner alone.
    it "keeps a personal invitation editable by its owner alone" do
      personal = create(:invitation, user: owner, organization: nil, title: "Mine")

      post "/graphql",
           params: { query:, variables: { externalId: personal.external_id, title: "Hijacked" } }.to_json,
           headers: headers_for(org_admin)

      expect(personal.reload.title).to eq("Mine")
    end
  end
end
