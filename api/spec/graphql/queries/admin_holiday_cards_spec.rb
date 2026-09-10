# typed: false

require "rails_helper"
require "jwt"

# The holiday card admin surface (#178). Holiday cards had none at all — no
# page, no query, no metric — so an abuse report about one had nowhere to land,
# and staff could not read a customer's card even to check it.
RSpec.describe "Admin holiday cards", type: :request do
  let(:admin) { create(:admin) }
  let(:customer) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:owner) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:other_owner) { create(:user, name: "Sam Guest", email: "sam@example.com") }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def customer_token = JWT.encode({ user_id: customer.id }, secret, "HS256")

  def exec(query, variables: {}, token: admin_token)
    post "/graphql",
      params: { query: query, variables: variables }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  describe "the list" do
    let(:query) do
      <<~GRAPHQL
        query AdminHolidayCards(
          $page: Int, $perPage: Int, $search: String, $status: String, $size: String,
          $templateId: String, $createdAfter: ISO8601DateTime, $createdBefore: ISO8601DateTime,
          $sort: String, $direction: String
        ) {
          adminHolidayCards(
            page: $page, perPage: $perPage, search: $search, status: $status, size: $size,
            templateId: $templateId, createdAfter: $createdAfter, createdBefore: $createdBefore,
            sort: $sort, direction: $direction
          ) {
            holidayCards {
              externalId
              title
              size
              templateId
              flagged
              deleted
              user { name email }
            }
            totalCount
            currentPage
            perPage
          }
        }
      GRAPHQL
    end

    def titles(variables)
      exec(query, variables: variables)
        .dig("data", "adminHolidayCards", "holidayCards").map { |card| card["title"] }
    end

    it "is not reachable with a customer JWT" do
      create(:holiday_card, user: owner)

      expect(exec(query, token: customer_token)["errors"].first["message"]).to eq "Not authorized"
    end

    it "lists every customer's cards, newest first, with the owner" do
      create(:holiday_card, title: "Older", user: owner, created_at: 3.days.ago)
      create(:holiday_card, title: "Newer", user: other_owner, created_at: 1.day.ago)

      data = exec(query, variables: { page: 1, perPage: 25 }).dig("data", "adminHolidayCards")

      expect(data["totalCount"]).to eq 2
      expect(data["holidayCards"].map { |card| card["title"] }).to eq %w[Newer Older]
      expect(data["holidayCards"].first["user"])
        .to eq("name" => "Sam Guest", "email" => "sam@example.com")
    end

    describe "search" do
      before do
        create(:holiday_card, title: "Shen family 2026", user: owner)
        create(:holiday_card, title: "Guest greetings", user: other_owner)
      end

      it "matches the title" do
        expect(titles(search: "shen")).to eq [ "Shen family 2026" ]
      end

      it "matches the external id" do
        card = HolidayCard.find_by(title: "Guest greetings")

        expect(titles(search: card.external_id)).to eq [ "Guest greetings" ]
      end

      it "matches the owner's email" do
        expect(titles(search: "dana@example.com")).to eq [ "Shen family 2026" ]
      end

      it "matches the owner's name, which is what finds a card with no title" do
        HolidayCard.find_by(title: "Guest greetings").update!(title: nil)

        expect(titles(search: "Sam").size).to eq 1
      end
    end

    describe "filters" do
      let!(:small) { create(:holiday_card, title: "Small", user: owner, size: "6x4") }
      let!(:large) do
        create(:holiday_card, title: "Large", user: owner, size: "6x9", template_id: "winter_portrait")
      end

      it "narrows to one size" do
        expect(titles(size: "6x9")).to eq [ "Large" ]
      end

      it "narrows to one template" do
        expect(titles(templateId: "winter_portrait")).to eq [ "Large" ]
      end

      it "narrows to flagged cards" do
        small.flag!

        expect(titles(status: "flagged")).to eq [ "Small" ]
      end

      # HolidayCard is default-scoped to `deleted_at: nil`, so this is the only
      # way admin sees a soft-deleted card at all.
      it "shows archived cards when the status filter asks for them" do
        small.delete!

        expect(titles({})).to eq [ "Large" ]
        expect(titles(status: "archived")).to eq [ "Small" ]
      end

      it "narrows to the cards nobody has acted on" do
        small.flag!

        expect(titles(status: "active")).to eq [ "Large" ]
      end

      it "rejects a locked status, which holiday cards cannot be" do
        body = exec(query, variables: { status: "locked" })

        expect(body["errors"].first["message"]).to eq "Invalid status: locked"
      end

      it "narrows to a created-at window" do
        small.update!(created_at: Time.utc(2026, 1, 10))
        large.update!(created_at: Time.utc(2026, 2, 1))

        expect(titles(createdAfter: "2026-01-01T00:00:00Z", createdBefore: "2026-02-01T00:00:00Z"))
          .to eq [ "Small" ]
      end

      it "composes — flagged 6x9 cards in one window" do
        large.update!(created_at: Time.utc(2026, 1, 10))
        large.flag!
        small.update!(created_at: Time.utc(2026, 1, 10))
        small.flag!

        expect(titles(
          status: "flagged", size: "6x9",
          createdAfter: "2026-01-01T00:00:00Z", createdBefore: "2026-02-01T00:00:00Z"
        )).to eq [ "Large" ]
      end
    end

    it "sorts by title and by last edit" do
      create(:holiday_card, title: "Anna", user: owner, updated_at: 1.day.ago)
      create(:holiday_card, title: "Zoe", user: owner, updated_at: 3.days.ago)

      expect(titles(sort: "title", direction: "asc")).to eq %w[Anna Zoe]
      expect(titles(sort: "updated_at", direction: "desc")).to eq %w[Anna Zoe]
    end

    it "clamps perPage" do
      create_list(:holiday_card, 2, user: owner)

      data = exec(query, variables: { perPage: 9999 }).dig("data", "adminHolidayCards")

      expect(data["perPage"]).to eq AdminListable::MAX_PER_PAGE
    end

    it "costs a fixed number of queries however many cards are listed" do
      create_list(:holiday_card, 5, user: owner)

      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
        queries << payload[:sql] if payload[:sql].match?(/FROM "(holiday_cards|users)"/)
      end
      exec(query, variables: { perPage: 25 })
      ActiveSupport::Notifications.unsubscribe(subscriber)

      # The count, the page, and one preload for the owner.
      expect(queries.size).to eq 3
    end
  end

  describe "one card" do
    let(:query) do
      <<~GRAPHQL
        query AdminHolidayCard($externalId: String!) {
          adminHolidayCard(externalId: $externalId) {
            externalId
            title
            size
            templateId
            designConfig
            flagged
            deleted
            photos { blobId }
            user { email }
          }
        }
      GRAPHQL
    end

    let!(:card) do
      create(:holiday_card, user: owner, design_config: { "version" => 1, "front" => {} })
    end

    it "is not reachable with a customer JWT" do
      body = exec(query, variables: { externalId: card.external_id }, token: customer_token)

      expect(body["errors"].first["message"]).to eq "Not authorized"
    end

    # Queries::HolidayCard resolves through `user.holiday_cards`, and an admin
    # JWT has no `current_user` — so before this, staff could not open any
    # customer's card at all.
    it "returns a card belonging to someone else, with its design config" do
      data = exec(query, variables: { externalId: card.external_id })
        .dig("data", "adminHolidayCard")

      expect(data["externalId"]).to eq card.external_id
      expect(data["designConfig"]).to eq("version" => 1, "front" => {})
      expect(data["user"]).to eq("email" => "dana@example.com")
      expect(data["photos"]).to eq []
    end

    it "still returns an archived card, so staff can see what they archived" do
      card.delete!

      data = exec(query, variables: { externalId: card.external_id })
        .dig("data", "adminHolidayCard")

      expect(data["deleted"]).to be true
    end

    it "returns nil for an id that does not exist" do
      body = exec(query, variables: { externalId: "NOPE" })

      expect(body.dig("data", "adminHolidayCard")).to be_nil
      expect(body["errors"]).to be_nil
    end
  end

  describe "metrics" do
    let(:query) do
      <<~GRAPHQL
        query BusinessMetrics {
          businessMetrics {
            holidayCardsLast1Day
            holidayCardsLast7Days
            holidayCardsLast30Days
            holidayCardsLast90Days
            holidayCardsLast180Days
          }
        }
      GRAPHQL
    end

    it "counts holiday cards, so the product stops being invisible on the dashboard" do
      create(:holiday_card, user: owner, created_at: 2.hours.ago)
      create(:holiday_card, user: owner, created_at: 10.days.ago)

      data = exec(query).dig("data", "businessMetrics")

      expect(data["holidayCardsLast1Day"]).to eq 1
      expect(data["holidayCardsLast30Days"]).to eq 2
    end
  end
end
