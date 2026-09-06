require "rails_helper"

# The postage wallet's read side (#145): the balance on the viewer, and the
# ledger history behind it. Both are scoped to the caller and both carry money
# as integer cents.
RSpec.describe "My postage ledger", type: :request do
  let(:user) { create(:user, name: "Ada Lovelace") }
  let(:stranger) { create(:user, name: "Mallory") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:query) do
    <<~GRAPHQL
      query MyPostageLedger($limit: Int) {
        viewer {
          creditBalance
          postageBalanceCents
        }
        myPostageLedger(limit: $limit) {
          id
          amountCents
          reason
          eventKind
          createdAt
        }
      }
    GRAPHQL
  end

  def exec(as:, limit: nil)
    token = JWT.encode({ user_id: as.id }, secret, "HS256")
    post "/graphql",
      params: { query: query, variables: { limit: limit } }.to_json,
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    JSON.parse(response.body)
  end

  def event(kind)
    { event_kind: kind, event_happened_at: Time.now.utc.iso8601(3), event_data: {} }
  end

  describe "postageBalanceCents" do
    it "is zero for a user who has never topped up, alongside their credit balance" do
      viewer = exec(as: user).dig("data", "viewer")

      expect(viewer["postageBalanceCents"]).to eq(0)
      expect(viewer["creditBalance"]).to eq(User::SIGNUP_CREDIT_GRANT)
    end

    it "returns the signed sum as an integer number of cents" do
      create(:postage_credit, user: user, amount_cents: 2000)
      create(:postage_credit, user: user, amount_cents: -86)

      balance = exec(as: user).dig("data", "viewer", "postageBalanceCents")

      expect(balance).to eq(1914)
      expect(balance).to be_an(Integer)
    end
  end

  describe "myPostageLedger" do
    it "returns the caller's rows, newest first, with amounts in cents" do
      create(:postage_credit, user: user, amount_cents: 2000, reason: "postage_purchased",
        events: [ event("postage_purchased") ], created_at: 2.days.ago)
      create(:postage_credit, user: user, amount_cents: -86, reason: "postcard_6x4",
        events: [ event("postage_spent_on_mail") ], created_at: 1.day.ago)

      rows = exec(as: user)["data"]["myPostageLedger"]

      expect(rows.map { |r| [ r["amountCents"], r["reason"], r["eventKind"] ] }).to eq([
        [ -86, "postcard_6x4", "postage_spent_on_mail" ],
        [ 2000, "postage_purchased", "postage_purchased" ]
      ])
    end

    it "is empty for a user with no postage history" do
      expect(exec(as: user)["data"]["myPostageLedger"]).to eq([])
    end

    it "does not leak another user's ledger" do
      create(:postage_credit, user: user, amount_cents: 2000, reason: "postage_purchased")

      result = exec(as: stranger)

      expect(result["data"]["myPostageLedger"]).to eq([])
      expect(result.dig("data", "viewer", "postageBalanceCents")).to eq(0)
    end

    it "returns a null eventKind for a row written without events" do
      create(:postage_credit, user: user, amount_cents: 500, reason: "manual", events: nil)

      expect(exec(as: user)["data"]["myPostageLedger"].first["eventKind"]).to be_nil
    end

    it "honours an explicit limit, taking the most recent rows" do
      3.times do |i|
        create(:postage_credit, user: user, amount_cents: (i + 1) * 100, created_at: i.days.ago)
      end

      rows = exec(as: user, limit: 2)["data"]["myPostageLedger"]

      expect(rows.map { |r| r["amountCents"] }).to eq([ 100, 200 ])
    end

    it "clamps a limit above the maximum rather than erroring" do
      create(:postage_credit, user: user, amount_cents: 100)

      rows = exec(as: user, limit: 10_000)["data"]["myPostageLedger"]

      expect(rows.length).to eq(1)
    end

    it "rejects an unauthenticated caller" do
      post "/graphql",
        params: { query: query, variables: {} }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(JSON.parse(response.body)["data"]&.dig("myPostageLedger")).to be_nil
    end
  end
end
