require "rails_helper"

# Creating into an organization, and the owner-or-org-admin gate that replaced
# the inline `card.user_id == user.id` checks.
RSpec.describe "organization-scoped cards", type: :request do
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

  describe "CreateCard" do
    let(:query) do
      <<~GRAPHQL
        mutation CreateCard($title: String!, $recipients: [String!]!, $styleIds: [ID!], $organizationId: ID) {
          createCard(input: {
            title: $title, recipients: $recipients, styleIds: $styleIds, organizationId: $organizationId
          }) {
            card { title organization { id } }
            errors
          }
        }
      GRAPHQL
    end

    # styleIds is optional in the schema but a required keyword on #resolve, so
    # it has to be sent even when empty.
    def create_card(user:, organization_id: nil)
      exec(query, { title: "Team card", recipients: [ "Ada" ], styleIds: [], organizationId: organization_id },
           user:, key: "createCard")
    end

    it "creates a card owned by the organization" do
      data = create_card(user: owner, organization_id: organization.id)

      expect(data["errors"]).to be_empty
      expect(data.dig("card", "organization", "id")).to eq(organization.id.to_s)
      expect(Card.last.organization_id).to eq(organization.id)
      expect(Card.last.user_id).to eq(owner.id)
    end

    it "refuses an organization the caller does not belong to, and spends no credit" do
      balance = stranger.credit_balance

      data = create_card(user: stranger, organization_id: organization.id)

      expect(data["card"]).to be_nil
      expect(data["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
      expect(stranger.reload.credit_balance).to eq(balance)
      expect(Card.count).to eq(0)
    end

    it "refuses an organization id that does not exist, and spends no credit" do
      balance = owner.credit_balance

      data = create_card(user: owner, organization_id: "0")

      expect(data["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
      expect(owner.reload.credit_balance).to eq(balance)
      expect(Card.count).to eq(0)
    end

    it "still creates a personal card when no organization is given" do
      data = create_card(user: owner)

      expect(data["errors"]).to be_empty
      expect(data.dig("card", "organization")).to be_nil
      expect(Card.last.organization_id).to be_nil
    end
  end

  describe "DeleteCard" do
    let!(:card) { create(:card, user: owner, organization:) }

    let(:query) do
      <<~GRAPHQL
        mutation DeleteCard($cardId: ID!) {
          deleteCard(input: { cardId: $cardId }) { success errors }
        }
      GRAPHQL
    end

    def delete_card(user:)
      exec(query, { cardId: card.external_id }, user:, key: "deleteCard")
    end

    it "lets the owner delete it" do
      expect(delete_card(user: owner)["success"]).to be(true)
    end

    it "lets an organization admin delete a card a colleague created" do
      expect(delete_card(user: org_admin)["success"]).to be(true)
      expect(card.reload.deleted).to be(true)
    end

    it "refuses an ordinary member" do
      expect(delete_card(user: member)["success"]).to be(false)
      expect(card.reload.deleted).to be(false)
    end

    it "refuses a non-member" do
      expect(delete_card(user: stranger)["success"]).to be(false)
      expect(card.reload.deleted).to be(false)
    end

    # Regression: nothing about a personal card's gate may have loosened.
    it "keeps a personal card deletable by its owner alone" do
      personal = create(:card, user: owner, organization: nil)

      post "/graphql",
           params: { query:, variables: { cardId: personal.external_id } }.to_json,
           headers: headers_for(org_admin)
      expect(JSON.parse(response.body).dig("data", "deleteCard", "success")).to be(false)
      expect(personal.reload.deleted).to be(false)
    end
  end

  describe "UpdateCard" do
    let!(:card) { create(:card, user: owner, organization:, title: "Old") }

    let(:query) do
      <<~GRAPHQL
        mutation UpdateCard($cardId: ID!, $title: String) {
          updateCard(input: { cardId: $cardId, title: $title }) { success errors }
        }
      GRAPHQL
    end

    def update_card(user:)
      exec(query, { cardId: card.external_id, title: "New" }, user:, key: "updateCard")
    end

    it "lets an organization admin edit a card a colleague created" do
      expect(update_card(user: org_admin)["success"]).to be(true)
      expect(card.reload.title).to eq("New")
    end

    it "refuses an ordinary member" do
      expect(update_card(user: member)["success"]).to be(false)
      expect(card.reload.title).to eq("Old")
    end
  end

  describe "DeliverCard" do
    let!(:card) { create(:card, :one_on_one, user: owner, organization:) }

    let(:query) do
      <<~GRAPHQL
        mutation DeliverCard($cardId: ID!, $recipientEmail: String!) {
          deliverCard(input: { cardId: $cardId, recipientEmail: $recipientEmail }) {
            card { externalId }
            errors
          }
        }
      GRAPHQL
    end

    def deliver(user:)
      exec(query, { cardId: card.external_id, recipientEmail: "to@example.com" }, user:, key: "deliverCard")
    end

    it "lets an organization admin deliver a colleague's card" do
      expect(deliver(user: org_admin)["errors"]).to be_empty
    end

    it "refuses an ordinary member" do
      expect(deliver(user: member)["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
    end
  end
end
