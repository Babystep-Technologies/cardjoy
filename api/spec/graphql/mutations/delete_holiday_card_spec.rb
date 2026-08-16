require "rails_helper"

RSpec.describe Mutations::DeleteHolidayCard, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:card) { create(:holiday_card, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation DeleteHolidayCard($externalId: String!) {
        deleteHolidayCard(input: { externalId: $externalId }) { success errors }
      }
    GRAPHQL
  end

  def exec(variables, request_headers: headers, gql: query, operation_name: nil)
    body = { query: gql, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  it "soft-deletes the card and removes it from myHolidayCards" do
    card

    result = exec({ externalId: card.external_id }).dig("data", "deleteHolidayCard")

    expect(result).to eq("success" => true, "errors" => [])
    # The row survives; only the default scope hides it.
    expect(HolidayCard.unscoped.find(card.id).deleted_at).to be_present

    mine = exec({}, gql: "query MyHolidayCards { myHolidayCards { externalId } }")
      .dig("data", "myHolidayCards")
    expect(mine).to be_empty
  end

  it "returns Not authorized for another user's card" do
    other = create(:holiday_card)

    result = exec({ externalId: other.external_id }).dig("data", "deleteHolidayCard")

    expect(result["errors"]).to eq([ "Not authorized" ])
    expect(other.reload.deleted_at).to be_nil
  end

  it "returns not found for an unknown external id" do
    result = exec({ externalId: "ZZZZZZZ" }).dig("data", "deleteHolidayCard")

    expect(result["errors"]).to eq([ "Holiday card not found" ])
  end

  it "rejects an unauthenticated caller smuggled into a public operation name" do
    smuggled = <<~GRAPHQL
      mutation Card($externalId: String!) {
        deleteHolidayCard(input: { externalId: $externalId }) { success errors }
      }
    GRAPHQL

    result = exec({ externalId: card.external_id }, request_headers: anonymous_headers, gql: smuggled, operation_name: "Card")
      .dig("data", "deleteHolidayCard")

    expect(result["errors"]).to eq([ "Not authenticated" ])
    expect(card.reload.deleted_at).to be_nil
  end
end
