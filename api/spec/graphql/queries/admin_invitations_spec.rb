# typed: false

require "rails_helper"
require "jwt"

# The invitation list the admin dashboard moderates from (#177). Invitations had
# no moderation columns at all before this, so `status` and the flag/lock/archive
# state on each row are new surface rather than a wider version of an old one.
RSpec.describe "Admin invitations", type: :request do
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
    exec(variables: variables).dig("data", "adminInvitations", "invitations").map { |i| i["title"] }
  end

  let(:query) do
    <<~GRAPHQL
      query AdminInvitations(
        $page: Int, $perPage: Int, $search: String, $status: String, $organizationId: ID,
        $createdAfter: ISO8601DateTime, $createdBefore: ISO8601DateTime,
        $sort: String, $direction: String
      ) {
        adminInvitations(
          page: $page, perPage: $perPage, search: $search, status: $status,
          organizationId: $organizationId, createdAfter: $createdAfter,
          createdBefore: $createdBefore, sort: $sort, direction: $direction
        ) {
          invitations {
            externalId
            title
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

  it "rejects a customer JWT" do
    create(:invitation, user: owner)

    expect(exec(token: user_token)["errors"].first["message"]).to eq "Not authorized"
  end

  it "returns every invitation newest first, unchanged from before the filters existed" do
    older = create(:invitation, title: "Older", user: owner, created_at: 3.days.ago)
    newer = create(:invitation, title: "Newer", user: owner, created_at: 1.day.ago)

    data = exec(variables: { page: 1, perPage: 25 }).dig("data", "adminInvitations")

    expect(data["totalCount"]).to eq 2
    expect(data["invitations"].map { |i| i["title"] }).to eq [ newer.title, older.title ]
  end

  it "reports moderation state, which every invitation starts clear of" do
    create(:invitation, user: owner)

    row = exec.dig("data", "adminInvitations", "invitations").first

    expect(row).to include("locked" => false, "flagged" => false, "deleted" => false)
  end

  describe "search" do
    before do
      create(:invitation, title: "Housewarming", user: owner)
      create(:invitation, title: "Retirement", user: other_owner)
    end

    it "matches the title" do
      expect(titles(search: "house")).to eq [ "Housewarming" ]
    end

    it "matches the external id" do
      invitation = Invitation.find_by(title: "Retirement")

      expect(titles(search: invitation.external_id)).to eq [ "Retirement" ]
    end

    it "matches the owner's email" do
      expect(titles(search: "dana@example.com")).to eq [ "Housewarming" ]
    end

    it "matches the owner's name" do
      expect(titles(search: "Sam")).to eq [ "Retirement" ]
    end
  end

  describe "filters" do
    let!(:one) { create(:invitation, title: "One", user: owner) }
    let!(:two) { create(:invitation, title: "Two", user: owner) }

    it "narrows to flagged invitations" do
      one.flag!

      expect(titles(status: "flagged")).to eq [ "One" ]
    end

    it "narrows to locked invitations" do
      two.lock!

      expect(titles(status: "locked")).to eq [ "Two" ]
    end

    it "reaches archived invitations, which the default scope hides" do
      one.delete!

      expect(titles({})).to eq [ "Two" ]
      expect(titles(status: "archived")).to eq [ "One" ]
    end

    it "narrows to the invitations nobody has acted on" do
      one.lock!

      expect(titles(status: "active")).to eq [ "Two" ]
    end

    it "narrows to one organization" do
      one.update!(organization: organization)

      expect(titles(organizationId: organization.id)).to eq [ "One" ]
    end

    it "narrows to a created-at window" do
      one.update!(created_at: Time.utc(2026, 1, 10))
      two.update!(created_at: Time.utc(2026, 2, 1))

      expect(titles(createdAfter: "2026-01-01T00:00:00Z", createdBefore: "2026-02-01T00:00:00Z"))
        .to eq [ "One" ]
    end

    it "composes — flagged invitations from one organization in one window" do
      one.update!(organization: organization, created_at: Time.utc(2026, 1, 10))
      one.flag!
      two.update!(organization: organization, created_at: Time.utc(2026, 1, 10))

      expect(titles(
        status: "flagged", organizationId: organization.id,
        createdAfter: "2026-01-01T00:00:00Z", createdBefore: "2026-02-01T00:00:00Z"
      )).to eq [ "One" ]
    end

    it "rejects an unknown status rather than ignoring it" do
      body = exec(variables: { status: "sideways" })

      expect(body["errors"].first["message"]).to eq "Invalid status: sideways"
    end
  end

  describe "sorting" do
    let!(:anna) { create(:invitation, title: "Anna", user: owner, created_at: 2.days.ago) }
    let!(:zoe) { create(:invitation, title: "Zoe", user: owner, created_at: 1.day.ago) }

    it "sorts by title" do
      expect(titles(sort: "title", direction: "asc")).to eq %w[Anna Zoe]
    end

    it "sorts by event date" do
      anna.update!(event_date: Date.new(2026, 12, 1))
      zoe.update!(event_date: Date.new(2026, 6, 1))

      expect(titles(sort: "event_date", direction: "asc")).to eq %w[Zoe Anna]
    end

    it "sorts by how many people replied" do
      create_list(:rsvp, 2, invitation: anna)

      expect(titles(sort: "rsvp_count", direction: "desc")).to eq %w[Anna Zoe]
    end

    it "defaults to newest first" do
      expect(titles({})).to eq %w[Zoe Anna]
    end
  end

  it "costs a fixed number of queries however many invitations are listed" do
    create_list(:invitation, 5, user: owner, organization: organization)

    queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
      queries << payload[:sql] if payload[:sql].match?(/FROM "(invitations|users|organizations)"/)
    end
    exec(variables: { perPage: 25 })
    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(queries.size).to eq 4
  end
end
