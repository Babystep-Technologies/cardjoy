require "rails_helper"

RSpec.describe Mutations::RemoveCardCoverImage, type: :request do
  let(:user) { create(:user) }
  let(:card) { create(:card, user: user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation RemoveCardCoverImage($cardId: ID!) {
        removeCardCoverImage(input: { cardId: $cardId }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  it "removes attached cover image successfully" do
    card.cover_image.attach(
      io: File.open(Rails.root.join("spec", "fixtures", "files", "test_image.jpg")),
      filename: "test_image.jpeg",
      content_type: "image/jpeg"
    )
    expect(card.cover_image).to be_attached

    post "/graphql",
      params: {
        query: query,
        variables: { cardId: card.external_id }
      }.to_json,
      headers: headers

    json = JSON.parse(response.body)
    data = json.dig("data", "removeCardCoverImage")

    expect(data["success"]).to be true
    expect(data["errors"]).to be_empty
    expect(card.reload.cover_image).not_to be_attached
  end

  it "returns an error if no cover image is attached" do
    expect(card.cover_image).not_to be_attached

    post "/graphql",
      params: {
        query: query,
        variables: { cardId: card.external_id }
      }.to_json,
      headers: headers

    json = JSON.parse(response.body)
    data = json.dig("data", "removeCardCoverImage")

    expect(data["success"]).to be false
    expect(data["errors"]).to include("No cover image to remove")
  end

  it "returns an error for unauthorized user" do
    post "/graphql",
      params: {
        query: query,
        variables: { cardId: card.external_id }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' } # No Authorization

    json = JSON.parse(response.body)

    expect(json["errors"]).to eq([ "Unauthorized" ])
  end
end
