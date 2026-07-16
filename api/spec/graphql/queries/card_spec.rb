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
end
