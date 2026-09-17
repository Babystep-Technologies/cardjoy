# typed: false

require "rails_helper"
require "jwt"

# Moderation for one post card (#178) — the actions the admin dashboard had
# for cards and not for post cards, so an abuse report about a printed card
# could not be acted on.
RSpec.describe "UpdatePostCardByAdmin", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let!(:card) { create(:post_card, user: user) }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation UpdatePostCardByAdmin($externalId: String!, $action: String!) {
        updatePostCardByAdmin(input: { externalId: $externalId, action: $action }) {
          postCard { externalId flagged deleted }
          errors
        }
      }
    GRAPHQL
  end

  def act(action, external_id: card.external_id, token: admin_token)
    post "/graphql",
      params: { query: query, variables: { externalId: external_id, action: action } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  it "rejects a customer JWT" do
    expect(act("flag", token: user_token)["errors"].first["message"]).to eq "Not authorized"
  end

  it "flags and unflags" do
    expect(act("flag").dig("data", "updatePostCardByAdmin", "postCard", "flagged")).to be true
    expect(act("unflag").dig("data", "updatePostCardByAdmin", "postCard", "flagged")).to be false
  end

  it "archives, and can still reach the card afterwards to restore it" do
    expect(act("archive").dig("data", "updatePostCardByAdmin", "postCard", "deleted")).to be true
    expect(PostCard.find_by(external_id: card.external_id)).to be_nil

    payload = act("unarchive").dig("data", "updatePostCardByAdmin")

    expect(payload["postCard"]["deleted"]).to be false
    expect(PostCard.find_by(external_id: card.external_id)).to be_present
  end

  it "reports an unknown action rather than doing nothing quietly" do
    payload = act("banish").dig("data", "updatePostCardByAdmin")

    expect(payload["errors"]).to eq [ "Invalid action" ]
    expect(payload["postCard"]).to be_nil
  end

  it "refuses lock, which a post card has no contributions to lock" do
    payload = act("lock").dig("data", "updatePostCardByAdmin")

    expect(payload["errors"]).to eq [ "Invalid action" ]
  end

  it "reports a missing card" do
    payload = act("flag", external_id: "nope").dig("data", "updatePostCardByAdmin")

    expect(payload["errors"]).to eq [ "Post card not found" ]
  end

  it "uses the card mutation's vocabulary, minus the two actions it cannot do" do
    expect(Mutations::UpdatePostCardByAdmin::VALID_ACTIONS)
      .to eq(Mutations::UpdateCardByAdmin::VALID_ACTIONS - %w[lock unlock])
  end
end
