# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::SetAnnualGoals, type: :request do
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
      mutation SetAnnualGoals($year: Int!, $dauTarget: Int!, $cardsAndInvitationsTarget: Int!) {
        setAnnualGoals(
          input: { year: $year, dauTarget: $dauTarget, cardsAndInvitationsTarget: $cardsAndInvitationsTarget }
        ) {
          annualGoal { year dauTarget cardsAndInvitationsTarget }
          errors
        }
      }
    GRAPHQL
  end

  def exec(year: 2026, dau_target: 1000, cards_target: 5000, token: admin_token)
    post "/graphql",
      params: {
        query: query,
        variables: { year: year, dauTarget: dau_target, cardsAndInvitationsTarget: cards_target }
      }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body).dig("data", "setAnnualGoals")
  end

  it "creates a goal for a year that has none yet" do
    data = exec(year: 2026, dau_target: 800, cards_target: 4000)

    expect(data["errors"]).to be_empty
    expect(data["annualGoal"]).to eq(
      "year" => 2026, "dauTarget" => 800, "cardsAndInvitationsTarget" => 4000
    )
  end

  it "replaces an existing year's goal rather than creating a second row" do
    create(:annual_goal, year: 2026, dau_target: 500, cards_and_invitations_target: 2000)

    data = exec(year: 2026, dau_target: 900, cards_target: 4500)

    expect(data["errors"]).to be_empty
    expect(data.dig("annualGoal", "dauTarget")).to eq 900
    expect(AnnualGoal.where(year: 2026).count).to eq 1
  end

  it "surfaces the model's own validation rather than raising" do
    data = exec(dau_target: 0)

    expect(data["annualGoal"]).to be_nil
    expect(data["errors"]).to be_present
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    body = post_and_parse(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "setAnnualGoals")).to be_nil
    expect(AnnualGoal.count).to eq 0
  end

  def post_and_parse(token:)
    post "/graphql",
      params: {
        query: query,
        variables: { year: 2026, dauTarget: 1000, cardsAndInvitationsTarget: 5000 }
      }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end
end
