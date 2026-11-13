require "rails_helper"

# Standalone registries (#245): the same upsertWishList mutation, with no invitation behind it.
RSpec.describe "Registry mutations", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def headers_for(account)
    token = JWT.encode({ user_id: account.id }, secret, "HS256")
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def run(query, variables, as: user)
    post "/graphql", params: { query: query, variables: variables }.to_json, headers: headers_for(as)
    JSON.parse(response.body)
  end

  let(:upsert) do
    <<~GRAPHQL
      mutation Upsert(
        $invitationExternalId: String, $registryExternalId: String, $title: String,
        $occasion: String, $eventDate: ISO8601Date, $items: [WishListItemInput!]
      ) {
        upsertWishList(input: {
          invitationExternalId: $invitationExternalId, registryExternalId: $registryExternalId,
          title: $title, occasion: $occasion, eventDate: $eventDate, items: $items
        }) {
          wishList { externalId title occasion eventDate standalone items { title } }
          errors
        }
      }
    GRAPHQL
  end

  describe "creating" do
    it "creates a standalone registry owned by the caller" do
      data = run(upsert, {
        title: "Sam's 30th", occasion: "birthday", eventDate: "2027-03-14",
        items: [ { title: "Cast-iron pan" } ]
      }).dig("data", "upsertWishList")

      expect(data["errors"]).to be_empty
      expect(data["wishList"]).to include(
        "title" => "Sam's 30th", "occasion" => "birthday", "eventDate" => "2027-03-14",
        "standalone" => true
      )
      expect(data["wishList"]["externalId"]).to match(/\A[a-z0-9]{10}\z/)

      list = user.wish_lists.sole
      expect(list.invitation).to be_nil
      expect(list.items.map(&:title)).to eq([ "Cast-iron pan" ])
    end

    it "keeps item order and the most-wanted flag the owner sets" do
      data = run(upsert, {
        title: "Order", items: [
          { title: "Second thing", priority: false }, { title: "First thing", priority: true }
        ]
      }).dig("data", "upsertWishList")

      expect(data["errors"]).to be_empty
      items = user.wish_lists.sole.items
      expect(items.map(&:title)).to eq([ "Second thing", "First thing" ])
      expect(items.map(&:priority)).to eq([ false, true ])
    end

    it "requires sign-in" do
      post "/graphql", params: { query: upsert, variables: { title: "x" } }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
      expect(WishList.count).to eq(0)
    end

    it "rejects an occasion we don't offer" do
      data = run(upsert, { title: "x", occasion: "bar-mitzvah-ish" }).dig("data", "upsertWishList")

      expect(data["wishList"]).to be_nil
      expect(data["errors"].join).to match(/Occasion/)
      expect(WishList.count).to eq(0)
    end

    it "refuses an invitation and a registry in the same call" do
      data = run(upsert, { invitationExternalId: "abc", registryExternalId: "def" })
        .dig("data", "upsertWishList")

      expect(data["errors"]).to eq([ "Pass an invitation or a registry, not both" ])
    end
  end

  describe "updating" do
    let!(:registry) { create(:wish_list, :standalone, user: user, title: "Old") }

    it "updates the caller's registry in place" do
      data = run(upsert, { registryExternalId: registry.external_id, title: "New", occasion: "wedding" })
        .dig("data", "upsertWishList")

      expect(data["errors"]).to be_empty
      expect(data["wishList"]["externalId"]).to eq(registry.external_id)
      expect(registry.reload).to have_attributes(title: "New", occasion: "wedding")
      expect(WishList.count).to eq(1)
    end

    it "lets the owner switch address sharing on (it starts off)" do
      expect(registry.share_address).to be(false)
      share = "mutation($id: String, $share: Boolean) { upsertWishList(input: { registryExternalId: $id, shareAddress: $share }) { wishList { shareAddress } errors } }"

      data = run(share, { id: registry.external_id, share: true }).dig("data", "upsertWishList")

      expect(data["wishList"]["shareAddress"]).to be(true)
      expect(registry.reload.share_address).to be(true)
    end

    it "treats someone else's registry as missing" do
      data = run(upsert, { registryExternalId: registry.external_id, title: "Hijacked" }, as: other)
        .dig("data", "upsertWishList")

      expect(data["errors"]).to eq([ "Registry not found" ])
      expect(registry.reload.title).to eq("Old")
    end
  end

  describe "deleting" do
    let(:delete) do
      <<~GRAPHQL
        mutation Delete($externalId: String!) {
          deleteRegistry(input: { externalId: $externalId }) { success errors }
        }
      GRAPHQL
    end
    let!(:registry) { create(:wish_list, :standalone, user: user) }

    it "deletes the caller's registry with its items and reservations" do
      item = create(:wish_list_item, wish_list: registry)
      create(:wish_list_reservation, wish_list_item: item)

      data = run(delete, { externalId: registry.external_id }).dig("data", "deleteRegistry")

      expect(data).to eq("success" => true, "errors" => [])
      expect([ WishList.count, WishListItem.count, WishListReservation.count ]).to eq([ 0, 0, 0 ])
    end

    it "won't delete someone else's registry" do
      data = run(delete, { externalId: registry.external_id }, as: other).dig("data", "deleteRegistry")

      expect(data).to eq("success" => false, "errors" => [ "Registry not found" ])
      expect(WishList.count).to eq(1)
    end
  end

  describe "resetting for next year" do
    let(:reset) do
      <<~GRAPHQL
        mutation Reset($externalId: String!) {
          resetRegistry(input: { externalId: $externalId }) {
            wishList { eventDate items { title remainingQuantity } }
            errors
          }
        }
      GRAPHQL
    end
    let(:list) { create(:wish_list, :standalone, user: user, event_date: Date.current - 20) }

    before do
      item = create(:wish_list_item, wish_list: list, title: "Cast-iron pan", quantity: 1)
      create(:wish_list_reservation, wish_list_item: item)
    end

    it "keeps the items, frees every claim and moves the date to the next occurrence ahead" do
      data = run(reset, { externalId: list.external_id }).dig("data", "resetRegistry")

      expect(data["errors"]).to be_empty
      expect(data["wishList"]["items"]).to eq([ { "title" => "Cast-iron pan", "remainingQuantity" => 1 } ])
      expect(WishListReservation.count).to eq(0)
      expect(list.reload.event_date).to be > Date.current
      expect(list.event_date).to be <= Date.current + 1.year
    end

    it "re-arms the owner reminder for the new date" do
      list.update_columns(event_reminded_at: Time.current)
      run(reset, { externalId: list.external_id })

      expect(list.reload.event_reminded_at).to be_nil
    end

    it "leaves someone else's registry alone" do
      data = run(reset, { externalId: list.external_id }, as: other).dig("data", "resetRegistry")

      expect(data["errors"]).to eq([ "Registry not found" ])
      expect(WishListReservation.count).to eq(1)
    end

    it "refuses an invitation's wish list" do
      invitation_list = create(:wish_list, user: user)

      data = run(reset, { externalId: invitation_list.external_id }).dig("data", "resetRegistry")

      expect(data["errors"]).to eq([ "Only a standalone registry can be reset" ])
    end
  end
end
