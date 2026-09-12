require "rails_helper"

RSpec.describe Mutations::TrackOneOnOneFlowStart, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }

  let(:query) do
    <<~GRAPHQL
      mutation TrackOneOnOneFlowStart {
        trackOneOnOneFlowStart(input: {}) {
          success
        }
      }
    GRAPHQL
  end

  def post_query(headers = {})
    post "/graphql",
      params: { query: query }.to_json,
      headers: headers.merge("Content-Type" => "application/json")
  end

  it "records a flow start for the current user" do
    expect {
      post_query("Authorization" => "Bearer #{token}")
    }.to change(OneOnOneFlowStart, :count).by(1)

    json = JSON.parse(response.body)
    expect(json.dig("data", "trackOneOnOneFlowStart", "success")).to eq(true)
    expect(OneOnOneFlowStart.last.user).to eq(user)
  end

  it "requires authentication and records nothing" do
    expect {
      post "/graphql",
        params: { operationName: "TrackOneOnOneFlowStart", query: query }.to_json,
        headers: { "Content-Type" => "application/json" }
    }.to change(OneOnOneFlowStart, :count).by(0)

    expect(response).to have_http_status(:unauthorized)
  end
end
