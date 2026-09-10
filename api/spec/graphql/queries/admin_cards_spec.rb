# typed: false

require "rails_helper"
require "jwt"

# The card list the admin dashboard moderates from (#177): search that finds a
# card by the id a customer pasted or by who owns it, filters that compose, and
# a sort that is no longer only newest-first.
RSpec.describe "Admin cards", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:owner) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:other_owner) { create(:user, name: "Sam Guest", email: "sam@example.com") }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: owner) }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  def exec(variables: {}, token: admin_token)
    post "/graphql",
      params: { query: query, variables: variables }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  def titles(variables)
    exec(variables: variables).dig("data", "adminCards", "cards").map { |card| card["title"] }
  end

  let(:query) do
    <<~GRAPHQL
      query AdminCards(
        $page: Int, $perPage: Int, $search: String, $kind: String, $status: String,
        $organizationId: ID, $occasion: String, $createdAfter: ISO8601DateTime,
        $createdBefore: ISO8601DateTime, $sort: String, $direction: String
      ) {
        adminCards(
          page: $page, perPage: $perPage, search: $search, kind: $kind, status: $status,
          organizationId: $organizationId, occasion: $occasion, createdAfter: $createdAfter,
          createdBefore: $createdBefore, sort: $sort, direction: $direction
        ) {
          cards {
            externalId
            title
            kind
            locked
            flagged
            deleted
            user { name email }
            organization { name }
          }
          totalCount
          currentPage
          perPage
        }
      }
    GRAPHQL
  end

  describe "authorization" do
    it "rejects a customer JWT" do
      create(:card, user: owner)

      body = exec(token: user_token)

      expect(body["errors"].first["message"]).to eq "Not authorized"
    end
  end

  describe "the default list" do
    it "returns every card newest first, unchanged from before the filters existed" do
      older = create(:card, title: "Older", user: owner, created_at: 3.days.ago)
      newer = create(:card, title: "Newer", user: owner, created_at: 1.day.ago)

      data = exec(variables: { page: 1, perPage: 25 }).dig("data", "adminCards")

      expect(data["totalCount"]).to eq 2
      expect(data["cards"].map { |card| card["title"] }).to eq [ newer.title, older.title ]
      expect(data["currentPage"]).to eq 1
      expect(data["perPage"]).to eq 25
    end

    it "shows the kind, owner, and organization admin could not see before" do
      create(:card, :one_on_one, title: "Just us", user: owner, organization: organization)

      card = exec.dig("data", "adminCards", "cards").first

      expect(card).to include("kind" => "one_on_one", "title" => "Just us")
      expect(card["user"]).to eq("name" => "Dana Host", "email" => "dana@example.com")
      expect(card["organization"]).to eq("name" => "Acme Corp")
    end

    it "leaves organization null for a personal card" do
      create(:card, user: owner)

      expect(exec.dig("data", "adminCards", "cards").first["organization"]).to be_nil
    end

    it "clamps perPage, and reports the size it actually served" do
      create_list(:card, 2, user: owner)

      data = exec(variables: { perPage: 9999 }).dig("data", "adminCards")

      expect(data["perPage"]).to eq AdminListable::MAX_PER_PAGE
      expect(data["cards"].size).to eq 2
    end

    it "treats perPage: 0 as one row rather than dividing by zero" do
      create_list(:card, 2, user: owner)

      data = exec(variables: { perPage: 0 }).dig("data", "adminCards")

      expect(data["perPage"]).to eq 1
      expect(data["cards"].size).to eq 1
    end
  end

  describe "search" do
    before do
      create(:card, title: "Birthday bash", user: owner)
      create(:card, title: "Farewell", user: other_owner)
    end

    it "matches the title" do
      expect(titles(search: "birthday")).to eq [ "Birthday bash" ]
    end

    it "matches the external id a customer pasted into a ticket" do
      card = Card.find_by(title: "Farewell")

      expect(titles(search: card.external_id)).to eq [ "Farewell" ]
    end

    it "matches the owner's email, so one customer's cards can be listed" do
      expect(titles(search: "dana@example.com")).to eq [ "Birthday bash" ]
    end

    it "matches the owner's name" do
      expect(titles(search: "Sam")).to eq [ "Farewell" ]
    end

    it "treats an underscore in the term literally rather than as a wildcard" do
      create(:card, title: "a_b", user: owner)
      create(:card, title: "axb", user: owner)

      expect(titles(search: "a_b")).to eq [ "a_b" ]
    end
  end

  describe "filters" do
    let!(:group) { create(:card, title: "Group", user: owner) }
    let!(:one_on_one) { create(:card, :one_on_one, title: "Solo", user: owner) }

    it "separates group cards from 1-on-1 cards" do
      expect(titles(kind: "one_on_one")).to eq [ "Solo" ]
      expect(titles(kind: "group")).to eq [ "Group" ]
    end

    it "narrows to flagged cards" do
      group.flag!

      expect(titles(status: "flagged")).to eq [ "Group" ]
    end

    it "narrows to locked cards" do
      one_on_one.lock!

      expect(titles(status: "locked")).to eq [ "Solo" ]
    end

    # Card is default-scoped to `deleted_at: nil`, so before this the archived
    # cards the dashboard offered to unarchive were unreachable.
    it "reaches archived cards, which the default scope hides" do
      group.delete!

      expect(titles(status: nil)).to eq [ "Solo" ]
      expect(titles(status: "archived")).to eq [ "Group" ]
    end

    it "narrows to the cards nobody has acted on" do
      group.flag!

      expect(titles(status: "active")).to eq [ "Solo" ]
    end

    it "narrows to one organization" do
      group.update!(organization: organization)

      expect(titles(organizationId: organization.id)).to eq [ "Group" ]
    end

    it "narrows to one occasion" do
      group.update!(occasion: "Birthday")

      expect(titles(occasion: "Birthday")).to eq [ "Group" ]
    end

    it "narrows to a created-at window, with an exclusive upper bound" do
      group.update!(created_at: Time.utc(2026, 1, 10))
      one_on_one.update!(created_at: Time.utc(2026, 2, 1))

      expect(titles(createdAfter: "2026-01-01T00:00:00Z", createdBefore: "2026-02-01T00:00:00Z"))
        .to eq [ "Group" ]
    end

    it "composes — flagged 1-on-1 cards from one organization in one window" do
      one_on_one.update!(organization: organization, created_at: Time.utc(2026, 1, 10))
      one_on_one.flag!
      # Matches every filter but `kind`.
      decoy = create(:card, title: "Decoy", user: owner, organization: organization,
        created_at: Time.utc(2026, 1, 10))
      decoy.flag!

      expect(titles(
        kind: "one_on_one", status: "flagged", organizationId: organization.id,
        createdAfter: "2026-01-01T00:00:00Z", createdBefore: "2026-02-01T00:00:00Z"
      )).to eq [ "Solo" ]
    end

    it "rejects an unknown status rather than ignoring it" do
      body = exec(variables: { status: "sideways" })

      expect(body["errors"].first["message"]).to eq "Invalid status: sideways"
    end

    it "rejects an unknown filter value shape by name" do
      body = exec(variables: { sort: "'; DROP TABLE cards; --" })

      expect(body["errors"].first["message"]).to start_with "Invalid sort:"
      expect(Card.count).to eq 2
    end
  end

  describe "sorting" do
    before do
      create(:card, title: "Anna", user: owner, created_at: 2.days.ago)
      create(:card, title: "Zoe", user: owner, created_at: 1.day.ago)
    end

    it "sorts by title" do
      expect(titles(sort: "title", direction: "asc")).to eq %w[Anna Zoe]
      expect(titles(sort: "title", direction: "desc")).to eq %w[Zoe Anna]
    end

    it "sorts by contribution volume" do
      create_list(:message, 2, card: Card.find_by(title: "Anna"))

      expect(titles(sort: "message_count", direction: "desc")).to eq %w[Anna Zoe]
    end

    it "defaults to newest first" do
      expect(titles({})).to eq %w[Zoe Anna]
    end
  end

  describe "pagination" do
    it "pages stably when every card shares a timestamp" do
      same_time = 1.day.ago
      create_list(:card, 5, user: owner, created_at: same_time)

      first = exec(variables: { page: 1, perPage: 2 }).dig("data", "adminCards", "cards")
      second = exec(variables: { page: 2, perPage: 2 }).dig("data", "adminCards", "cards")
      third = exec(variables: { page: 3, perPage: 2 }).dig("data", "adminCards", "cards")

      ids = (first + second + third).map { |card| card["externalId"] }
      expect(ids.uniq.size).to eq 5
    end
  end

  # The list has never selected the owner, so the columns added here would have
  # cost a query per row.
  it "costs a fixed number of queries however many cards are listed" do
    create_list(:card, 5, user: owner, organization: organization)

    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
      queries << payload[:sql] if payload[:sql].match?(/FROM "(cards|users|organizations)"/)
    end
    exec(variables: { perPage: 25 })
    ActiveSupport::Notifications.unsubscribe(subscriber)

    # The count, the page, and one preload each for the owner and organization.
    expect(queries.size).to eq 4
  end
end
