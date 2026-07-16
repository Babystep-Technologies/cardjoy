require "rails_helper"

RSpec.describe Mutations::DeliverCard, type: :request do
  let(:user) { create(:user) }
  let(:card) { create(:card, :one_on_one, user:) }
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
      mutation DeliverCard($cardId: ID!, $recipientEmail: String!) {
        deliverCard(input: { cardId: $cardId, recipientEmail: $recipientEmail }) {
          card { externalId }
          errors
        }
      }
    GRAPHQL
  end

  def post_query(variables, extra_headers = {})
    post "/graphql",
      params: { operationName: "DeliverCard", query:, variables: }.to_json,
      headers: headers.merge(extra_headers)
  end

  it "enqueues a one_on_one_delivery email to the recipient" do
    expect {
      post_query(cardId: card.external_id, recipientEmail: "friend@example.com")
    }.to have_enqueued_mail(CardMailer, :one_on_one_delivery).with("friend@example.com", card)

    json = JSON.parse(response.body)
    data = json.dig("data", "deliverCard")
    expect(data["errors"]).to be_empty
    expect(data.dig("card", "externalId")).to eq(card.external_id)
  end

  it "does not let a non-owner deliver the card" do
    other_user = create(:user)
    other_token = JWT.encode({ user_id: other_user.id }, secret, 'HS256')

    expect {
      post_query(
        { cardId: card.external_id, recipientEmail: "friend@example.com" },
        "Authorization" => "Bearer #{other_token}"
      )
    }.not_to have_enqueued_mail(CardMailer, :one_on_one_delivery)

    json = JSON.parse(response.body)
    data = json.dig("data", "deliverCard")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "requires authentication" do
    expect {
      post "/graphql",
        params: {
          operationName: "DeliverCard",
          query:,
          variables: { cardId: card.external_id, recipientEmail: "friend@example.com" }
        }.to_json,
        headers: { "Content-Type" => "application/json" } # no Authorization header
    }.not_to have_enqueued_mail(CardMailer, :one_on_one_delivery)

    json = JSON.parse(response.body)
    data = json.dig("data", "deliverCard")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to eq([ "Not authenticated" ])
  end

  it "returns an error when the card does not exist" do
    expect {
      post_query(cardId: "ZZZZZZZ", recipientEmail: "friend@example.com")
    }.not_to have_enqueued_mail(CardMailer, :one_on_one_delivery)

    json = JSON.parse(response.body)
    data = json.dig("data", "deliverCard")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to eq([ "Card not found" ])
  end
end
