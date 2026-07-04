require 'rails_helper'

RSpec.describe Mutations::UpdateCard, type: :request do
  include ActionDispatch::TestProcess::FixtureFile

  let(:user) { create(:user) }
  let(:card) { create(:card, user: user, title: "Old Title", recipients: [ "Old" ]) }
  let(:styles) { create_list(:style, 2) }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }

  let(:headers) do
    {
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation UpdateCard(
        $cardId: ID!
        $title: String
        $recipients: [String!]
        $occasion: String
        $styleIds: [ID!]
        $coverImageUrl: String
        $coverImageFile: Upload
      ) {
        updateCard(
          input: {
            cardId: $cardId
            title: $title
            recipients: $recipients
            occasion: $occasion
            styleIds: $styleIds
            coverImageUrl: $coverImageUrl
            coverImageFile: $coverImageFile
          }
        ) {
          success
          errors
        }
      }
    GRAPHQL
  end

  it "updates the card title, recipients, and styles" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          cardId: card.external_id,
          title: "Updated Title",
          occasion: "Birthday",
          recipients: [ "Alice", "Bob" ],
          styleIds: styles.map(&:id)
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateCard")
    expect(data["success"]).to be true
    expect(card.reload.title).to eq("Updated Title")
    expect(card.recipients).to eq([ "Alice", "Bob" ])
    expect(card.styles.map(&:id)).to match_array(styles.map(&:id))
  end

  it "updates the cover image via file upload" do
    file = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")

    post "/graphql",
      params: {
        operations: {
          query: query,
          variables: {
            cardId: card.external_id,
            coverImageFile: nil
          }
        }.to_json,
        map: { "0" => [ "variables.coverImageFile" ] }.to_json,
        "0" => file
      },
      headers: headers.merge("Content-Type" => "multipart/form-data")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    expect(json.dig("data", "updateCard", "success")).to be true
    expect(card.reload.cover_image).to be_attached
  end

  it "updates the cover image via remote URL" do
    url = "https://placehold.co/600x400/EEE/31343C.png"
    stub_request(:get, url).to_return(status: 200, body: "\x89PNG", headers: { "Content-Type" => "image/png" })

    post "/graphql",
      params: {
        query: query,
        variables: {
          cardId: card.external_id,
          coverImageUrl: url
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    expect(json.dig("data", "updateCard", "success")).to be true
    expect(card.reload.cover_image).to be_attached
  end

  it "returns error if user is unauthenticated" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          cardId: card.external_id,
          title: "No Access"
        }
      }.to_json,
      headers: { "Content-Type" => "application/json" }

    json = JSON.parse(response.body)
    expect(json["errors"]).to eq([ "Unauthorized" ])
  end

  it "returns error if card does not belong to user" do
    other_user = create(:user)
    other_card = create(:card, user: other_user)

    post "/graphql",
      params: {
        query: query,
        variables: {
          cardId: other_card.external_id,
          title: "Hack Attempt"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["data"]["updateCard"]["success"]).to be false
    expect(json["data"]["updateCard"]["errors"]).to include("Card not found or not owned by user")
  end
end
