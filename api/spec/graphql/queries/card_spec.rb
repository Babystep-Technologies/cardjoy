require "rails_helper"

RSpec.describe Queries::Card, type: :request do
  let(:user) { create(:user) }

  # The exact selection web/src/pages/Card/Viewable.tsx sends. Narrowing it hides
  # non-null fields that resolve to nil — which is how every 1-on-1 card shipped
  # unviewable: Message.title was String! over a nullable column, and no spec
  # selected it.
  let(:query) do
    <<~GRAPHQL
      query Card($cardId: ID!, $showFlaggedMessages: Boolean!) {
        card(cardId: $cardId, showFlaggedMessages: $showFlaggedMessages) {
          title
          slug
          locked
          flagged
          messageLimitReached
          kind
          user { id }
          recipients
          coverImageUrl
          styles { name kind value }
          messages {
            id
            title
            text
            imageUrl
            displayName
            flagged
            user { id name }
            reactedUserIds
            kind
          }
          guestMessages {
            id
            title
            name
            text
            imageUrl
            flagged
            reactedUserIds
            kind
          }
        }
      }
    GRAPHQL
  end

  # Posted as JSON, like Apollo does: form encoding would turn the Boolean into
  # the string "false". operationName matters too — GraphqlController#public_operation?
  # reads it to let the reveal page work signed out.
  def post_query(card)
    post "/graphql",
      params: {
        query:,
        operationName: "Card",
        variables: { cardId: card.external_id, showFlaggedMessages: false }
      }.to_json,
      headers: { "Content-Type" => "application/json" }
    JSON.parse(response.body)
  end

  context "a one-on-one card" do
    let(:card) { create(:card, :one_on_one, user:) }

    before { create(:message, card:, user:, title: nil) }

    it "resolves every field the reveal page selects" do
      json = post_query(card)

      expect(json["errors"]).to be_nil
      expect(json.dig("data", "card", "kind")).to eq("one_on_one")
      expect(json.dig("data", "card", "messages").length).to eq(1)
    end

    it "returns a null title rather than failing the query" do
      json = post_query(card)

      expect(json.dig("data", "card", "messages", 0, "title")).to be_nil
      expect(json.dig("data", "card", "messages", 0, "text")).to be_present
    end

    it "exposes an attached effect style" do
      card.styles << create(:style, :effect)

      json = post_query(card)

      effect = json.dig("data", "card", "styles").find { |s| s["kind"] == "effect" }
      expect(effect["value"]).to eq("confetti")
    end
  end

  context "a group card with a guest message" do
    let(:card) { create(:card, user:) }

    it "tolerates nil title, text, and name on a guest message" do
      create(:guest_message, card:, title: nil, text: nil, name: nil)

      json = post_query(card)

      expect(json["errors"]).to be_nil
      guest = json.dig("data", "card", "guestMessages", 0)
      expect(guest["title"]).to be_nil
      expect(guest["text"]).to be_nil
      expect(guest["name"]).to be_nil
    end
  end

  # Organization ownership must not reach the public share link (#122). Access
  # on this path is the unguessable external_id plus require_login_to_contribute
  # — never membership — so an org-owned card reveals and accepts contributions
  # exactly like a personal one.
  context "a card an organization owns, opened signed out" do
    let(:organization) { create(:organization) }
    let(:card) { create(:card, user:, organization:) }

    before { create(:organization_membership, organization:, user:) }

    it "still renders for an anonymous visitor" do
      create(:message, card:, user:, title: nil)

      json = post_query(card)

      expect(json["errors"]).to be_nil
      expect(json.dig("data", "card", "title")).to be_present
      expect(json.dig("data", "card", "messages").length).to eq(1)
    end

    it "still accepts an anonymous contribution" do
      mutation = <<~GRAPHQL
        mutation UpsertMessage($cardId: ID!, $text: String!, $guestName: String) {
          upsertMessage(input: { cardId: $cardId, text: $text, guestName: $guestName }) {
            success
            errors
          }
        }
      GRAPHQL

      post "/graphql",
        params: {
          query: mutation,
          operationName: "UpsertMessage",
          variables: { cardId: card.external_id, text: "Congrats!", guestName: "A guest" }
        }.to_json,
        headers: { "Content-Type" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      expect(json.dig("data", "upsertMessage", "errors")).to be_empty
      expect(card.guest_messages.count).to eq(1)
    end

    # The opt-in path: passing organizationId asks for a context-aware read, and
    # that one *is* membership-gated.
    it "refuses a non-member who asks for it in the organization's context" do
      stranger = create(:user)
      secret = Rails.application.credentials.dig(:jwt, :secret)
      token = JWT.encode({ user_id: stranger.id }, secret, "HS256")

      post "/graphql",
        params: {
          query: <<~GRAPHQL,
            query Card($cardId: ID!, $showFlaggedMessages: Boolean!, $organizationId: ID) {
              card(cardId: $cardId, showFlaggedMessages: $showFlaggedMessages, organizationId: $organizationId) {
                title
              }
            }
          GRAPHQL
          operationName: "Card",
          variables: { cardId: card.external_id, showFlaggedMessages: false, organizationId: organization.id }
        }.to_json,
        headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }

      json = JSON.parse(response.body)
      expect(json["errors"].first["message"]).to eq(Queries::BaseQuery::NOT_AUTHORIZED_ERROR)
    end
  end
end
