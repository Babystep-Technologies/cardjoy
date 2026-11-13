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
end
