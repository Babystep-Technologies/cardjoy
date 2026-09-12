# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Queries::AdminOneOnOneMetrics, type: :request do
  let(:admin) { create(:admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token(user) = JWT.encode({ user_id: user.id }, secret, "HS256")

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  let(:query) do
    <<~GRAPHQL
      query AdminOneOnOneMetrics($window: MetricsWindow!) {
        adminOneOnOneMetrics(window: $window) {
          window
          startDate
          endDate
          flowStarts
          oneOnOneCardsCreated
          creationCompletionRate
          occasionsSaved
          usersWithOccasions
          occasionsSavedPerUser
          remindersSent
          cardsFromReminder
          reminderConversionRate
          oneOnOneSenders
          crossedOverToGroupCard
          crossOverRate
        }
      }
    GRAPHQL
  end

  def data(window: "THIRTY_DAYS", token: admin_token)
    post "/graphql",
      params: { query: query, variables: { window: window } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body).dig("data", "adminOneOnOneMetrics")
  end

  around do |example|
    travel_to(Time.utc(2026, 6, 15, 12, 0, 0)) { example.run }
  end

  it "requires an admin" do
    user = create(:user)
    post "/graphql",
      params: { query: query, variables: { window: "THIRTY_DAYS" } }.to_json,
      headers: headers_for(user_token(user))

    json = JSON.parse(response.body)
    expect(json.dig("data", "adminOneOnOneMetrics")).to be_nil
    expect(json["errors"].first["message"]).to eq("Not authorized")
  end

  describe "creation completion rate" do
    it "divides one-on-one cards created by flow starts, both windowed" do
      user = create(:user)
      create_list(:one_on_one_flow_start, 4, user: user, created_at: 1.day.ago)
      create(:one_on_one_flow_start, user: user, created_at: 35.days.ago) # outside
      create(:card, :one_on_one, user: user, created_at: 1.day.ago)
      create(:card, created_at: 1.day.ago) # group card, excluded from the numerator

      result = data

      expect(result["flowStarts"]).to eq 4
      expect(result["oneOnOneCardsCreated"]).to eq 1
      expect(result["creationCompletionRate"]).to eq 0.25
    end

    it "is 0.0, not an error, when there are no flow starts" do
      result = data

      expect(result["flowStarts"]).to eq 0
      expect(result["creationCompletionRate"]).to eq 0.0
    end
  end

  describe "occasions saved per user" do
    it "divides occasions created in the window by the distinct users who added one" do
      contact_a = create(:contact)
      contact_b = create(:contact)
      create_list(:occasion, 3, contact: contact_a, created_at: 1.day.ago)
      create(:occasion, contact: contact_b, created_at: 1.day.ago)
      create(:occasion, contact: contact_a, created_at: 35.days.ago) # outside

      result = data

      expect(result["occasionsSaved"]).to eq 4
      expect(result["usersWithOccasions"]).to eq 2
      expect(result["occasionsSavedPerUser"]).to eq 2.0
    end
  end

  describe "reminder to card conversion" do
    it "divides cards attributed to a reminder by occasions reminded in the window" do
      occasion_a = create(:occasion, last_reminded_at: 1.day.ago)
      occasion_b = create(:occasion, last_reminded_at: 1.day.ago)
      create(:occasion, last_reminded_at: 35.days.ago) # outside

      create(:card, :one_on_one, source_occasion: occasion_a, created_at: 1.day.ago)
      create(:card, :one_on_one, created_at: 1.day.ago) # no attribution

      result = data

      expect(result["remindersSent"]).to eq 2
      expect(result["cardsFromReminder"]).to eq 1
      expect(result["reminderConversionRate"]).to eq 0.5

      # occasion_b unused in assertions but keeps the "2 reminders" count honest
      expect(occasion_b.last_reminded_at).to be_present
    end
  end

  describe "1-on-1 to group card cross-over" do
    it "counts a user whose first-ever group card postdates their first-ever one-on-one card" do
      crossed_over_user = create(:user)
      create(:card, :one_on_one, user: crossed_over_user, created_at: 10.days.ago)
      create(:card, user: crossed_over_user, created_at: 2.days.ago)

      never_crossed_user = create(:user)
      create(:card, :one_on_one, user: never_crossed_user, created_at: 10.days.ago)

      outside_cohort_user = create(:user)
      create(:card, :one_on_one, user: outside_cohort_user, created_at: 40.days.ago)
      create(:card, user: outside_cohort_user, created_at: 2.days.ago)

      result = data

      expect(result["oneOnOneSenders"]).to eq 2
      expect(result["crossedOverToGroupCard"]).to eq 1
      expect(result["crossOverRate"]).to eq 0.5
    end

    it "does not count a group card created before the user's first one-on-one card" do
      user = create(:user)
      create(:card, user: user, created_at: 20.days.ago)
      create(:card, :one_on_one, user: user, created_at: 10.days.ago)

      result = data

      expect(result["oneOnOneSenders"]).to eq 1
      expect(result["crossedOverToGroupCard"]).to eq 0
    end
  end
end
