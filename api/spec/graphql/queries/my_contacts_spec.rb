require "rails_helper"

RSpec.describe "MyContacts", type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      query MyContacts {
        myContacts { id name occasions { id kind } }
      }
    GRAPHQL
  end

  def exec
    post "/graphql", params: { query: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "myContacts")
  end

  it "returns only the caller's contacts, with their occasions" do
    mine = create(:contact, user:, name: "Mine")
    create(:occasion, contact: mine, kind: "Birthday")
    create(:contact, name: "Someone Else")

    result = exec
    expect(result.map { |c| c["name"] }).to eq([ "Mine" ])
    expect(result.first["occasions"].map { |o| o["kind"] }).to eq([ "Birthday" ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql", params: { query: }.to_json, headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
