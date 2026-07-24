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
        $contributorPrompt: String
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
            contributorPrompt: $contributorPrompt
            styleIds: $styleIds
            coverImageUrl: $coverImageUrl
            coverImageFile: $coverImageFile
          }
        ) {
          card {
            id
            title
            occasion
            contributorPrompt
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

  it "creates a card with a contributor prompt" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "With Prompt",
          recipients: [ "Sarah" ],
          occasion: "New Job",
          styleIds: [],
          contributorPrompt: "It's Sarah's first day — what career advice would you give her?"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createCard")
    expect(data["errors"]).to be_empty
    expect(data["card"]["contributorPrompt"]).to eq("It's Sarah's first day — what career advice would you give her?")
    expect(Card.last.contributor_prompt).to eq("It's Sarah's first day — what career advice would you give her?")
  end

  describe "credit deduction" do
    def create_card
      post "/graphql",
        params: { query: query, variables: { title: "Charged", recipients: [ "Bob" ], styleIds: [] } }.to_json,
        headers: headers.merge("Content-Type" => "application/json")
      JSON.parse(response.body).dig("data", "createCard")
    end

    it "deducts exactly one credit on success" do
      expect { create_card }.to change { user.reload.credit_balance }.by(-1)

      debit = user.credits.order(:id).last
      expect(debit.amount).to eq(-1)
      expect(debit.events.first["event_kind"]).to eq("card_created")
    end

    it "blocks the create and charges nothing when the balance is empty" do
      user.credits.destroy_all
      card_count = Card.count
      credit_count = Credit.count

      result = create_card

      expect(result["card"]).to be_nil
      expect(result["errors"]).to include("Not enough credits")
      expect(Card.count).to eq(card_count)
      expect(Credit.count).to eq(credit_count)
    end
  end
end
