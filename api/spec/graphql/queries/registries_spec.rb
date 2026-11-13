require "rails_helper"

RSpec.describe "Registry queries", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def headers_for(account)
    return { "Content-Type" => "application/json" } unless account

    token = JWT.encode({ user_id: account.id }, secret, "HS256")
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def run(query, variables = {}, as: user, operation: nil)
    post "/graphql", params: { query: query, variables: variables, operationName: operation }.to_json,
      headers: headers_for(as)
    JSON.parse(response.body)
  end

  describe "myRegistries" do
    let(:query) { "{ myRegistries { externalId title standalone } }" }

    it "lists the caller's registries, standalone and invitation-based, newest first" do
      older = create(:wish_list, :standalone, user: user, title: "Older", created_at: 2.days.ago)
      newer = create(:wish_list, invitation: create(:invitation, user: user), title: "Newer")
      create(:wish_list, :standalone, user: other, title: "Not mine")

      rows = run(query).dig("data", "myRegistries")

      expect(rows.map { |r| r["externalId"] }).to eq([ newer.external_id, older.external_id ])
      expect(rows.map { |r| r["standalone"] }).to eq([ false, true ])
    end

    it "requires sign-in" do
      run("query MyRegistries { myRegistries { externalId } }", as: nil, operation: "MyRegistries")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "registry" do
    let(:query) { "query GetRegistry($id: String!) { registry(externalId: $id) { externalId title } }" }

    it "returns a visible registry to anyone, signed in or not" do
      list = create(:wish_list, :standalone, user: user, visible: true)

      expect(run(query, { id: list.external_id }, as: nil, operation: "GetRegistry").dig("data", "registry", "externalId"))
        .to eq(list.external_id)
    end

    it "hides an unpublished registry from everyone but its owner" do
      list = create(:wish_list, :standalone, user: user, visible: false)

      expect(run(query, { id: list.external_id }, as: other, operation: "GetRegistry").dig("data", "registry")).to be_nil
      expect(run(query, { id: list.external_id }, as: user, operation: "GetRegistry").dig("data", "registry", "title")).to eq(list.title)
    end

    it "exposes the owner's first name but nothing more about them" do
      list = create(:wish_list, :standalone, user: create(:user, name: "Sam Rivera"))
      query = "query GetRegistry($id: String!) { registry(externalId: $id) { ownerFirstName } }"

      data = run(query, { id: list.external_id }, as: nil, operation: "GetRegistry")

      expect(data.dig("data", "registry", "ownerFirstName")).to eq("Sam")
    end

    it "returns nil for an unknown id" do
      expect(run(query, { id: "nope" }, operation: "GetRegistry").dig("data", "registry")).to be_nil
    end

    describe "who reserved what" do
      let(:query) do
        "query GetRegistry($id: String!) { registry(externalId: $id) { items { reservations { guestName } } } }"
      end
      let(:list) { create(:wish_list, :standalone, user: user, surprise_mode: surprise) }

      before { create(:wish_list_reservation, wish_list_item: create(:wish_list_item, wish_list: list)) }

      def reservations_seen_by(account)
        run(query, { id: list.external_id }, as: account, operation: "GetRegistry")
          .dig("data", "registry", "items", 0, "reservations")
      end

      context "with surprise mode on" do
        let(:surprise) { true }

        it "hides reservations from everyone, including the owner" do
          expect(reservations_seen_by(user)).to eq([])
          expect(reservations_seen_by(other)).to eq([])
        end
      end

      context "with surprise mode off" do
        let(:surprise) { false }

        it "shows reservations to the owner only" do
          expect(reservations_seen_by(user).size).to eq(1)
          expect(reservations_seen_by(other)).to eq([])
          expect(reservations_seen_by(nil)).to eq([])
        end
      end
    end
  end

  describe "wishListClaim" do
    let(:query) do
      "query GetWishListClaim($token: String!) { wishListClaim(token: $token) { wishListItemId purchased } }"
    end

    it "reads back a guest's own claim from the token alone" do
      reservation = create(:wish_list_reservation, purchased_at: Time.current)

      data = run(query, { token: reservation.token }, as: nil, operation: "GetWishListClaim")

      expect(data.dig("data", "wishListClaim")).to eq(
        "wishListItemId" => reservation.wish_list_item_id.to_s, "purchased" => true
      )
    end

    it "reads an unknown token as nothing" do
      data = run(query, { token: "nope" }, as: nil, operation: "GetWishListClaim")

      expect(data.dig("data", "wishListClaim")).to be_nil
    end
  end

  describe "where to send the gift" do
    let(:query) do
      "query GetWishListClaim($token: String!) { wishListClaim(token: $token) " \
        "{ shipToName shipTo { addressLine1 city postalCode countryCode } } }"
    end
    let(:owner) { create(:user, :with_return_address, name: "Sam Rivera") }
    let(:list) { create(:wish_list, :standalone, user: owner, share_address: sharing) }
    let(:reservation) { create(:wish_list_reservation, wish_list_item: create(:wish_list_item, wish_list: list)) }

    def claim_for(token)
      run(query, { token: token }, as: nil, operation: "GetWishListClaim").dig("data", "wishListClaim")
    end

    context "when the owner shares their address" do
      let(:sharing) { true }

      it "shows it to someone holding a claim" do
        claim = claim_for(reservation.token)

        expect(claim["shipToName"]).to eq("Sam Rivera")
        expect(claim["shipTo"]).to include("addressLine1" => "123 Market St", "city" => "San Francisco")
      end

      it "shows nothing without a valid claim token" do
        expect(claim_for("nope")).to be_nil
      end

      it "shows nothing when the owner has no complete address saved" do
        owner.update!(HasReturnAddress::ADDRESS_FIELDS.index_with { nil })

        expect(claim_for(reservation.token)).to include("shipTo" => nil, "shipToName" => nil)
      end

      it "hides it again the moment the owner stops sharing" do
        list.update!(share_address: false)

        expect(claim_for(reservation.token)).to include("shipTo" => nil, "shipToName" => nil)
      end
    end

    context "when the owner does not share (the default)" do
      let(:sharing) { false }

      it "never reveals it" do
        expect(claim_for(reservation.token)).to include("shipTo" => nil, "shipToName" => nil)
      end
    end

    it "is never on the public registry itself" do
      list = create(:wish_list, :standalone, user: owner, share_address: true)
      public_query = "query GetRegistry($id: String!) { registry(externalId: $id) { shareAddress } }"

      data = run(public_query, { id: list.external_id }, as: nil, operation: "GetRegistry")

      expect(data.dig("data", "registry")).to eq("shareAddress" => true)
      expect(Types::WishListType.fields.keys).not_to include("shipTo", "returnAddress", "address")
    end
  end

  describe "insights" do
    let(:list) { create(:wish_list, :standalone, user: user, surprise_mode: true) }
    let(:query) { "query GetRegistry($id: String!) { registry(externalId: $id) { insights { itemCount coveredCount purchasedCount } } }" }

    before do
      pan = create(:wish_list_item, wish_list: list, quantity: 1)
      towels = create(:wish_list_item, wish_list: list, quantity: 2)
      create(:wish_list_item, wish_list: list, quantity: 1)
      create(:wish_list_reservation, wish_list_item: pan, purchased_at: Time.current)
      create(:wish_list_reservation, wish_list_item: towels, quantity: 1)
    end

    it "gives the owner totals only, even in surprise mode" do
      data = run(query, { id: list.external_id }, operation: "GetRegistry").dig("data", "registry", "insights")

      expect(data).to eq("itemCount" => 3, "coveredCount" => 1, "purchasedCount" => 1)
    end

    it "is hidden from everyone else" do
      expect(run(query, { id: list.external_id }, as: other, operation: "GetRegistry").dig("data", "registry", "insights")).to be_nil
      expect(run(query, { id: list.external_id }, as: nil, operation: "GetRegistry").dig("data", "registry", "insights")).to be_nil
    end
  end

  describe "thank-you list" do
    let(:query) { "query GetRegistry($id: String!) { registry(externalId: $id) { thankYouUnlocked thankYouList { guestName guestEmail itemTitle purchased } } }" }
    let(:list) { create(:wish_list, :standalone, user: user, surprise_mode: true, event_date: nil) }

    before do
      item = create(:wish_list_item, wish_list: list, title: "Cast-iron pan")
      create(:wish_list_reservation, wish_list_item: item, guest_name: "Alex", purchased_at: Time.current)
    end

    def registry(as: user)
      run(query, { id: list.external_id }, as: as, operation: "GetRegistry").dig("data", "registry")
    end

    it "stays locked in surprise mode until the event has passed" do
      expect(registry).to eq("thankYouUnlocked" => false, "thankYouList" => [])

      list.update!(event_date: Date.current + 1)
      expect(registry["thankYouList"]).to eq([])

      list.update!(event_date: Date.current - 1)
      expect(registry["thankYouUnlocked"]).to be(true)
      expect(registry["thankYouList"]).to eq([ { "guestName" => "Alex", "guestEmail" => "alex.guest@example.com", "itemTitle" => "Cast-iron pan", "purchased" => true } ])
    end

    it "is open straight away when surprise mode is off" do
      list.update!(surprise_mode: false)

      expect(registry["thankYouList"].size).to eq(1)
    end

    it "is never shown to anyone but the owner, even once unlocked" do
      list.update!(surprise_mode: false)

      expect(registry(as: other)["thankYouList"]).to eq([])
      expect(registry(as: nil)["thankYouList"]).to eq([])
    end
  end
end
