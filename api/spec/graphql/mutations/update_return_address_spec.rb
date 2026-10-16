require "rails_helper"

RSpec.describe Mutations::UpdateReturnAddress, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation UpdateReturnAddress(
        $addressLine1: String, $addressLine2: String, $city: String,
        $region: String, $postalCode: String, $countryCode: String
      ) {
        updateReturnAddress(
          input: {
            addressLine1: $addressLine1, addressLine2: $addressLine2, city: $city,
            region: $region, postalCode: $postalCode, countryCode: $countryCode
          }
        ) {
          user { returnAddress { addressLine1 addressLine2 city region postalCode countryCode complete } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, request_headers: headers)
    post "/graphql", params: { query:, variables: }.to_json, headers: request_headers
    JSON.parse(response.body).dig("data", "updateReturnAddress")
  end

  it "sets a complete return address" do
    data = exec(
      { addressLine1: "123 Market St", city: "San Francisco", postalCode: "94103", countryCode: "us" }
    )

    expect(data["errors"]).to be_empty
    expect(data["user"]["returnAddress"]).to include(
      "addressLine1" => "123 Market St", "city" => "San Francisco",
      "postalCode" => "94103", "countryCode" => "US", "complete" => true
    )
    expect(user.reload).to be_return_address_complete
  end

  it "leaves the stored address alone when the address fields are omitted" do
    user.update!(
      return_address_line1: "123 Market St", return_address_city: "San Francisco",
      return_address_postal_code: "94103", return_address_country_code: "US"
    )

    data = exec({ city: nil })

    expect(data["errors"]).to be_empty
    expect(data["user"]["returnAddress"]).to include("addressLine1" => "123 Market St")
  end

  it "updates one field without touching the rest" do
    user.update!(
      return_address_line1: "123 Market St", return_address_city: "San Francisco",
      return_address_postal_code: "94103", return_address_country_code: "US"
    )

    data = exec({ addressLine1: "456 Mission St" })

    expect(data["errors"]).to be_empty
    expect(data["user"]["returnAddress"]).to include("addressLine1" => "456 Mission St", "city" => "San Francisco")
  end

  it "rejects an edit that would leave the address partial" do
    user.update!(
      return_address_line1: "123 Market St", return_address_city: "San Francisco",
      return_address_postal_code: "94103", return_address_country_code: "US"
    )

    data = exec({ postalCode: "" })

    expect(data["user"]).to be_nil
    expect(data["errors"]).to include("Return address postal code #{HasReturnAddress::INCOMPLETE_ADDRESS_MESSAGE}")
    expect(user.reload.return_address_postal_code).to eq("94103")
  end

  it "clears the whole address when every field is given as an empty string" do
    user.update!(
      return_address_line1: "123 Market St", return_address_city: "San Francisco",
      return_address_postal_code: "94103", return_address_country_code: "US"
    )

    data = exec(
      { addressLine1: "", addressLine2: "", city: "", region: "", postalCode: "", countryCode: "" }
    )

    expect(data["errors"]).to be_empty
    expect(data["user"]["returnAddress"]).to include("addressLine1" => nil, "complete" => false)
    expect(user.reload).not_to be_return_address_complete
  end

  it "refuses an anonymous caller" do
    post "/graphql", params: { query:, variables: { city: "San Francisco" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    result = JSON.parse(response.body)

    expect(result["data"]&.fetch("updateReturnAddress", nil)).to be_nil
    expect(result.fetch("errors", [])).not_to be_empty
  end
end
