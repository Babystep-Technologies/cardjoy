# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Queries::AdminAnnualGoals, type: :request do
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
      query AdminAnnualGoals($year: Int) {
        adminAnnualGoals(year: $year) {
          year
          dauTarget
          cardsAndInvitationsTarget
        }
      }
    GRAPHQL
  end

  def exec(year: nil, token: admin_token)
    post "/graphql",
      params: { query: query, variables: { year: year } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  it "returns the goal for the requested year" do
    create(:annual_goal, year: 2025, dau_target: 500, cards_and_invitations_target: 2000)

    data = exec(year: 2025).dig("data", "adminAnnualGoals")

    expect(data).to eq(
      "year" => 2025, "dauTarget" => 500, "cardsAndInvitationsTarget" => 2000
    )
  end

  it "defaults to the current calendar year when none is given" do
    travel_to(Time.utc(2026, 6, 1)) do
      create(:annual_goal, year: 2026, dau_target: 750, cards_and_invitations_target: 3000)

      data = exec.dig("data", "adminAnnualGoals")

      expect(data["year"]).to eq 2026
    end
  end

  it "returns null when no goal has been set for that year" do
    data = exec(year: 2099)

    expect(data.dig("data", "adminAnnualGoals")).to be_nil
    expect(data["errors"]).to be_nil
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "adminAnnualGoals")).to be_nil
  end
end
