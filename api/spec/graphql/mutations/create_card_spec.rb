require "rails_helper"

RSpec.describe Mutations::CreateCard, type: :request do
  include ActionDispatch::TestProcess::FixtureFile

  let(:user) { create(:user) }
  let(:styles) { create_list(:style, 3) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation CreateCard(
        $title: String!
        $occasion: String
        $recipients: [String!]!
        $styleIds: [ID!]
        $coverImageUrl: String
        $coverImageFile: Upload
      ) {
        createCard(
          input: {
            title: $title
            recipients: $recipients
            occasion: $occasion
            styleIds: $styleIds
            coverImageUrl: $coverImageUrl
            coverImageFile: $coverImageFile
          }
        ) {
          card {
            id
            title
            occasion
            recipients
            styles { id name }
          }
          errors
        }
      }
    GRAPHQL
  end

  it "creates a card with a cover image file" do
    file = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")

    post "/graphql",
      params: {
        operations: {
          query: query,
          variables: {
            title: "With Upload",
            recipients: [ "Bob" ],
            occasion: "Birthday",
            styleIds: styles.map(&:id),
            coverImageFile: nil # placeholder for map
          }
        }.to_json,
        map: { "0" => [ "variables.coverImageFile" ] }.to_json,
        "0" => file
      },
      headers: headers.merge("Content-Type" => "multipart/form-data")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createCard")
    expect(data["errors"]).to be_empty
    expect(data["card"]).to be_present
    expect(Card.last.cover_image).to be_attached
  end

  it "creates a card with a cover image URL" do
    url = "https://placehold.co/600x400/EEE/31343C.png"
    stub_request(:get, url).to_return(status: 200, body: "\x89PNG", headers: { "Content-Type" => "image/png" })

    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "With URL",
          recipients: [ "Alice" ],
          occasion: "Anniversary",
          styleIds: styles.map(&:id),
          coverImageUrl: url
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createCard")
    expect(data["errors"]).to be_empty
    expect(data["card"]).to be_present
    expect(Card.last.cover_image).to be_attached
  end

  it "creates a card without a cover image file (coverImageFile: empty hash)" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "No Cover File",
          recipients: [ "Dana" ],
          occasion: "Graduation",
          styleIds: styles.map(&:id),
          coverImageFile: nil
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createCard")
    expect(data["errors"]).to be_empty
    expect(data["card"]).to be_present
    expect(Card.last.cover_image).not_to be_attached
  end
end
