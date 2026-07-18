require "rails_helper"

RSpec.describe Mutations::CancelScheduledDelivery, type: :request do
  let(:user) { create(:user) }
  let(:card) do
    create(:card, :one_on_one, user:,
      deliver_at: 3.days.from_now.change(usec: 0), deliver_to_email: "friend@example.com")
  end
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation CancelScheduledDelivery($cardId: ID!) {
        cancelScheduledDelivery(input: { cardId: $cardId }) {
          card { externalId deliverAt deliverToEmail }
          errors
        }
      }
    GRAPHQL
  end

  def post_query(variables, extra_headers = {})
    post "/graphql",
      params: { operationName: "CancelScheduledDelivery", query:, variables: }.to_json,
      headers: headers.merge(extra_headers)
  end

  it "clears the schedule so the pending job no-ops" do
    post_query(cardId: card.external_id)

    json = JSON.parse(response.body)
    data = json.dig("data", "cancelScheduledDelivery")
    expect(data["errors"]).to be_empty
    expect(data.dig("card", "deliverAt")).to be_nil
    expect(data.dig("card", "deliverToEmail")).to be_nil
    expect(card.reload.deliver_at).to be_nil
    expect(card.deliver_to_email).to be_nil
  end

  it "does not let a non-owner cancel the schedule" do
    other_user = create(:user)
    other_token = JWT.encode({ user_id: other_user.id }, secret, 'HS256')

    post_query({ cardId: card.external_id }, "Authorization" => "Bearer #{other_token}")

    json = JSON.parse(response.body)
    data = json.dig("data", "cancelScheduledDelivery")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(card.reload.deliver_at).not_to be_nil
  end

  it "requires authentication" do
    post "/graphql",
      params: {
        operationName: "CancelScheduledDelivery",
        query:,
        variables: { cardId: card.external_id }
      }.to_json,
      headers: { "Content-Type" => "application/json" } # no Authorization header

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to include("Unauthorized")
    expect(card.reload.deliver_at).not_to be_nil
  end

  it "returns an error when the card does not exist" do
    post_query(cardId: "ZZZZZZZ")

    json = JSON.parse(response.body)
    data = json.dig("data", "cancelScheduledDelivery")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to eq([ "Card not found" ])
  end
end
