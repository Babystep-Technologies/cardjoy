# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Queries::AdminMetrics, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  let(:query) do
    <<~GRAPHQL
      query AdminMetrics($window: MetricsWindow!) {
        adminMetrics(window: $window) {
          window
          startDate
          endDate
          newUsers
          groupCards
          oneOnOneCards
          invitations
          holidayCards
          rsvpsGoing
          rsvpsMaybe
          rsvpsNotGoing
          totalAttendees
          currentDauRolling7d
          dauBackfillBoundary
          dailySeries { date dau dauRolling7d groupCards oneOnOneCards invitations holidayCards rsvps }
        }
      }
    GRAPHQL
  end

  def exec(window:, token: admin_token)
    post "/graphql",
      params: { query: query, variables: { window: window } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  def data(window:, token: admin_token)
    exec(window: window, token: token).dig("data", "adminMetrics")
  end

  around do |example|
    # A fixed "today" so window boundaries are deterministic.
    travel_to(Time.utc(2026, 6, 15, 12, 0, 0)) { example.run }
  end

  describe "the THIRTY_DAYS window" do
    it "excludes rows outside the trailing 30 days" do
      create(:card, created_at: 35.days.ago) # outside
      create(:card, created_at: 5.days.ago) # inside

      result = data(window: "THIRTY_DAYS")

      expect(result["startDate"]).to eq (Date.current - 29).iso8601
      expect(result["endDate"]).to eq Date.current.iso8601
      expect(result["groupCards"]).to eq 1
    end
  end

  describe "per-product breakdown" do
    it "splits cards by kind and counts every product separately" do
      create(:card, created_at: 1.day.ago) # group, the factory default
      create(:card, :one_on_one, created_at: 1.day.ago)
      create(:invitation, created_at: 1.day.ago)
      create(:holiday_card, created_at: 1.day.ago)

      result = data(window: "THIRTY_DAYS")

      expect(result).to include(
        "groupCards" => 1,
        "oneOnOneCards" => 1,
        "invitations" => 1,
        "holidayCards" => 1
      )
    end

    it "excludes archived (soft-deleted) rows from creation totals" do
      create(:card, created_at: 1.day.ago, deleted_at: 1.hour.ago)

      result = data(window: "THIRTY_DAYS")

      expect(result["groupCards"]).to eq 0
    end
  end

  describe "RSVP breakdown" do
    it "counts by status and sums attendees with their +1s" do
      invitation = create(:invitation)
      create(:rsvp, invitation: invitation, status: "going", additional_guests_count: 2, created_at: 1.day.ago)
      create(:rsvp, invitation: invitation, status: "going", additional_guests_count: 0, created_at: 1.day.ago)
      create(:rsvp, invitation: invitation, status: "maybe", created_at: 1.day.ago)
      create(:rsvp, invitation: invitation, status: "not-going", created_at: 1.day.ago)

      result = data(window: "THIRTY_DAYS")

      expect(result).to include("rsvpsGoing" => 2, "rsvpsMaybe" => 1, "rsvpsNotGoing" => 1)
      # 2 going RSVPs + 2 additional guests = 4
      expect(result["totalAttendees"]).to eq 4
    end
  end

  describe "the YEAR_TO_DATE window at the January 1st edge" do
    it "starts and ends on the same day when today is New Year's Day" do
      # Block form here would nest inside the outer `around`'s travel_to and
      # raise; the non-block form just re-stubs, which is fine since the
      # around hook's travel_back cleans up at the end of the example either way.
      travel_to Time.utc(2027, 1, 1, 8, 0, 0)
      result = data(window: "YEAR_TO_DATE")

      expect(result["startDate"]).to eq "2027-01-01"
      expect(result["endDate"]).to eq "2027-01-01"
    end

    it "starts at January 1st on any later date in the year" do
      result = data(window: "YEAR_TO_DATE")

      expect(result["startDate"]).to eq "2026-01-01"
      expect(result["endDate"]).to eq Date.current.iso8601
    end
  end

  describe "the ALL_TIME window" do
    it "starts at the earliest row across the counted products" do
      create(:card, created_at: Time.utc(2025, 3, 1))
      create(:invitation, created_at: Time.utc(2025, 6, 1))

      result = data(window: "ALL_TIME")

      expect(result["startDate"]).to eq "2025-03-01"
    end

    it "falls back to today when there is no data at all" do
      result = data(window: "ALL_TIME")

      expect(result["startDate"]).to eq Date.current.iso8601
    end
  end

  describe "DAU and its 7-day rolling average" do
    it "counts distinct users per day and averages the trailing 7 days" do
      users = create_list(:user, 3)

      # Day -1: 2 distinct users active (one recorded twice, which the unique
      # index collapses to one row).
      create(:user_daily_activity, user: users[0], activity_date: 1.day.ago.to_date)
      create(:user_daily_activity, user: users[1], activity_date: 1.day.ago.to_date)
      # Day 0 (today): 1 user active.
      create(:user_daily_activity, user: users[2], activity_date: Date.current)

      result = data(window: "THIRTY_DAYS")
      by_date = result["dailySeries"].index_by { |row| row["date"] }

      expect(by_date[1.day.ago.to_date.iso8601]["dau"]).to eq 2
      expect(by_date[Date.current.iso8601]["dau"]).to eq 1
      # Rolling average over the 7 days ending today: (2 + 1) / 7.
      expect(result["currentDauRolling7d"]).to be_within(0.001).of(3.0 / 7)
    end

    it "exposes the backfill boundary as a fixed date" do
      result = data(window: "THIRTY_DAYS")

      expect(result["dauBackfillBoundary"]).to eq UserDailyActivity::BACKFILL_CUTOFF_ON.iso8601
    end
  end

  describe "caching" do
    it "does not share a cached value between two different windows" do
      real_cache = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(real_cache)

      create(:card, created_at: 50.days.ago) # inside NINETY_DAYS, outside THIRTY_DAYS

      thirty = data(window: "THIRTY_DAYS")
      ninety = data(window: "NINETY_DAYS")

      # If the cache key didn't include the window, one of these would leak
      # the other's count instead of each reflecting its own range.
      expect(thirty["groupCards"]).to eq 0
      expect(ninety["groupCards"]).to eq 1
      expect(thirty["window"]).to eq "THIRTY_DAYS"
      expect(ninety["window"]).to eq "NINETY_DAYS"
    end
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    body = exec(window: "THIRTY_DAYS", token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "adminMetrics")).to be_nil
  end

  it "answers an unauthenticated request with 401" do
    exec(window: "THIRTY_DAYS", token: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
