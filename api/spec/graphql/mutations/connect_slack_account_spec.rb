require 'rails_helper'

RSpec.describe Mutations::ConnectSlackAccount, type: :request do
  let(:user) { create(:user) }
  let(:jwt_secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:auth_token) { JWT.encode({ user_id: user.id }, jwt_secret, 'HS256') }
  let(:headers) { { 'Authorization' => "Bearer #{auth_token}", 'Content-Type' => 'application/json' } }

  let(:query) do
    <<~GRAPHQL
      mutation ConnectSlackAccount($input: ConnectSlackAccountInput!) {
        connectSlackAccount(input: $input) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def state_token(slack_user_id:, slack_team_id:, exp: 30.minutes.from_now.to_i)
    JWT.encode(
      { slack_user_id: slack_user_id, slack_team_id: slack_team_id, exp: exp },
      jwt_secret
    )
  end

  def run_mutation(state)
    post "/graphql",
      params: { query: query, variables: { input: { state: state } } }.to_json,
      headers: headers
    JSON.parse(response.body).dig("data", "connectSlackAccount")
  end

  context "with a valid state token" do
    it "creates a SlackUserConnection for the current user" do
      state = state_token(slack_user_id: "U123", slack_team_id: "T456")

      expect {
        result = run_mutation(state)
        expect(result["success"]).to be true
        expect(result["errors"]).to be_empty
      }.to change { SlackUserConnection.count }.by(1)

      connection = SlackUserConnection.last
      expect(connection.user).to eq(user)
      expect(connection.slack_user_id).to eq("U123")
      expect(connection.slack_team_id).to eq("T456")
    end

    it "updates an existing connection if the Slack user reconnects" do
      other_user = create(:user)
      create(:slack_user_connection, user: other_user, slack_user_id: "U123", slack_team_id: "T456")
      state = state_token(slack_user_id: "U123", slack_team_id: "T456")

      expect {
        result = run_mutation(state)
        expect(result["success"]).to be true
      }.not_to change { SlackUserConnection.count }

      expect(SlackUserConnection.find_by(slack_user_id: "U123", slack_team_id: "T456").user).to eq(user)
    end
  end

  context "with an expired state token" do
    it "returns an error and does not create a connection" do
      state = state_token(slack_user_id: "U123", slack_team_id: "T456", exp: 1.hour.ago.to_i)

      expect {
        result = run_mutation(state)
        expect(result["success"]).to be false
        expect(result["errors"].first).to include("expired")
      }.not_to change { SlackUserConnection.count }
    end
  end

  context "with an invalid state token" do
    it "returns an error and does not create a connection" do
      expect {
        result = run_mutation("not.a.valid.jwt")
        expect(result["success"]).to be false
        expect(result["errors"].first).to include("Invalid")
      }.not_to change { SlackUserConnection.count }
    end
  end

  context "when not authenticated" do
    it "returns a 401 unauthorized response" do
      state = state_token(slack_user_id: "U123", slack_team_id: "T456")

      post "/graphql",
        params: { query: query, variables: { input: { state: state } } }.to_json,
        headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to include("Unauthorized")
    end
  end
end
