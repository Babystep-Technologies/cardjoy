require "rails_helper"

# `user(id:)` takes no ownership check — any signed-in caller can look up any
# user by id (pre-existing: it already exposes email and creditBalance this
# way). returnAddress is a home address, and must not ride along (#233).
RSpec.describe "user", type: :request do
  let(:caller) { create(:user) }
  let(:other) do
    create(:user, :with_return_address, name: "Someone Else")
  end

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: caller.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      query User($id: ID!) {
        user(id: $id) {
          id
          name
          returnAddress { addressLine1 complete }
        }
      }
    GRAPHQL
  end

  def exec(id)
    post "/graphql", params: { query: query, variables: { id: id } }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "user")
  end

  it "does not expose another user's return address" do
    result = exec(other.id)

    expect(result["name"]).to eq("Someone Else")
    expect(result["returnAddress"]).to be_nil
  end

  it "exposes the caller's own return address when looking themselves up by id" do
    caller.update!(
      return_address_line1: "123 Market St", return_address_city: "San Francisco",
      return_address_postal_code: "94103", return_address_country_code: "US"
    )

    result = exec(caller.id)

    expect(result["returnAddress"]).to include("addressLine1" => "123 Market St", "complete" => true)
  end
end
