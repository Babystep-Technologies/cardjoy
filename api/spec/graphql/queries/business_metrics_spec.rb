# typed: false

require "rails_helper"

RSpec.describe "BusinessMetrics", type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) do
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      query BusinessMetrics {
        businessMetrics {
          usersLast1Day
          usersLast7Days
          usersLast30Days
          usersLast90Days
          usersLast180Days
          cardsLast1Day
          cardsLast7Days
          cardsLast30Days
          cardsLast90Days
          cardsLast180Days
          invitationsLast1Day
          invitationsLast7Days
          invitationsLast30Days
          invitationsLast90Days
          invitationsLast180Days
          rsvpsLast1Day
          rsvpsLast7Days
          rsvpsLast30Days
          rsvpsLast90Days
          rsvpsLast180Days
          rsvpsGoingLast30Days
          rsvpsMaybeLast30Days
          rsvpsNotGoingLast30Days
          totalAttendeesLast30Days
        }
      }
    GRAPHQL
  end

  def exec_query
    post "/graphql",
      params: { query: query }.to_json,
      headers: headers
  end

  before do
    # Clear existing data to ensure clean test state
    User.delete_all
    Card.delete_all
    Invitation.delete_all
    Rsvp.delete_all
  end

  describe "invitation metrics" do
    it "counts invitations created in different time periods" do
      # Create invitations at different times
      create(:invitation, created_at: 2.days.ago)
      create(:invitation, created_at: 10.days.ago)
      create(:invitation, created_at: 40.days.ago)
      create(:invitation, created_at: 100.days.ago)
      create(:invitation, created_at: 200.days.ago)

      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig("data", "businessMetrics")

      expect(data["invitationsLast1Day"]).to eq(0)
      expect(data["invitationsLast7Days"]).to eq(1)
      expect(data["invitationsLast30Days"]).to eq(2)
      expect(data["invitationsLast90Days"]).to eq(3)
      expect(data["invitationsLast180Days"]).to eq(4)
    end
  end

  describe "RSVP metrics" do
    it "counts RSVPs created in different time periods" do
      invitation = create(:invitation)

      # Create RSVPs at different times
      create(:rsvp, invitation: invitation, created_at: 2.days.ago)
      create(:rsvp, invitation: invitation, created_at: 10.days.ago)
      create(:rsvp, invitation: invitation, created_at: 40.days.ago)
      create(:rsvp, invitation: invitation, created_at: 100.days.ago)
      create(:rsvp, invitation: invitation, created_at: 200.days.ago)

      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig("data", "businessMetrics")

      expect(data["rsvpsLast1Day"]).to eq(0)
      expect(data["rsvpsLast7Days"]).to eq(1)
      expect(data["rsvpsLast30Days"]).to eq(2)
      expect(data["rsvpsLast90Days"]).to eq(3)
      expect(data["rsvpsLast180Days"]).to eq(4)
    end

    it "counts RSVPs by status in last 30 days" do
      invitation = create(:invitation)

      # Create RSVPs with different statuses within 30 days
      create(:rsvp, invitation: invitation, status: "going", created_at: 5.days.ago)
      create(:rsvp, invitation: invitation, status: "going", created_at: 10.days.ago)
      create(:rsvp, invitation: invitation, status: "maybe", created_at: 15.days.ago)
      create(:rsvp, invitation: invitation, status: "not-going", created_at: 20.days.ago)

      # Create RSVPs outside 30 days (should not be counted)
      create(:rsvp, invitation: invitation, status: "going", created_at: 40.days.ago)

      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig("data", "businessMetrics")

      expect(data["rsvpsGoingLast30Days"]).to eq(2)
      expect(data["rsvpsMaybeLast30Days"]).to eq(1)
      expect(data["rsvpsNotGoingLast30Days"]).to eq(1)
    end
  end

  describe "total attendees calculation" do
    it "calculates total attendees including additional guests" do
      invitation = create(:invitation)

      # Create going RSVPs with additional guests
      create(:rsvp, invitation: invitation, status: "going", additional_guests_count: 2, created_at: 5.days.ago)
      create(:rsvp, invitation: invitation, status: "going", additional_guests_count: 1, created_at: 10.days.ago)
      create(:rsvp, invitation: invitation, status: "going", additional_guests_count: 0, created_at: 15.days.ago)

      # Create non-going RSVPs (should not be counted)
      create(:rsvp, invitation: invitation, status: "maybe", additional_guests_count: 3, created_at: 20.days.ago)
      create(:rsvp, invitation: invitation, status: "not-going", additional_guests_count: 1, created_at: 25.days.ago)

      # Create going RSVP outside 30 days (should not be counted)
      create(:rsvp, invitation: invitation, status: "going", additional_guests_count: 5, created_at: 40.days.ago)

      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig("data", "businessMetrics")

      # 3 going RSVPs + (2 + 1 + 0) additional guests = 6 total attendees
      expect(data["totalAttendeesLast30Days"]).to eq(6)
    end

    it "returns 0 when there are no going RSVPs" do
      invitation = create(:invitation)

      create(:rsvp, invitation: invitation, status: "maybe", created_at: 5.days.ago)
      create(:rsvp, invitation: invitation, status: "not-going", created_at: 10.days.ago)

      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig("data", "businessMetrics")

      expect(data["totalAttendeesLast30Days"]).to eq(0)
    end
  end

  describe "user and card metrics (existing behavior)" do
    it "still counts users and cards correctly" do
      # Create users and cards at different times
      create(:user, created_at: 2.days.ago)
      create(:card, created_at: 2.days.ago)

      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig("data", "businessMetrics")

      expect(data["usersLast7Days"]).to be >= 2 # at least the authenticated user and the one we created
      expect(data["cardsLast7Days"]).to eq(1)
    end
  end
end
