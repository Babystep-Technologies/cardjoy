require "rails_helper"

RSpec.describe Mutations::CreateOneOnOneCard, type: :request do
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
      mutation CreateOneOnOneCard(
        $title: String!
        $recipient: String!
        $text: String!
        $displayName: String
        $occasion: String
        $styleIds: [ID!]
        $coverImageUrl: String
        $coverImageFile: Upload
      ) {
        createOneOnOneCard(
          input: {
            title: $title
            recipient: $recipient
            text: $text
            displayName: $displayName
            occasion: $occasion
            styleIds: $styleIds
            coverImageUrl: $coverImageUrl
            coverImageFile: $coverImageFile
          }
        ) {
          card {
            id
            title
            kind
            occasion
            recipients
            styles { id name }
            messages { id text displayName }
          }
          errors
        }
      }
    GRAPHQL
  end

  def post_query(variables, extra_headers = {})
    post "/graphql",
      params: {
        query: query,
        variables: variables
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json").merge(extra_headers)
  end

  it "creates a one_on_one card owned by the current user plus one message" do
    expect {
      post_query(
        title: "For You",
        recipient: "Sam",
        text: "Happy birthday!",
        displayName: "Alex",
        occasion: "Birthday",
        styleIds: styles.map(&:id)
      )
    }.to change(Card, :count).by(1).and change(Message, :count).by(1)

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createOneOnOneCard")
    expect(data["errors"]).to be_empty

    card = data["card"]
    expect(card["kind"]).to eq("one_on_one")
    expect(card["recipients"]).to eq([ "Sam" ])
    expect(card["occasion"]).to eq("Birthday")
    expect(card["styles"].map { |s| s["id"] }).to match_array(styles.map { |s| s["id"].to_s })
    expect(card["messages"].length).to eq(1)
    expect(card["messages"].first["text"]).to eq("Happy birthday!")
    expect(card["messages"].first["displayName"]).to eq("Alex")

    persisted = Card.last
    expect(persisted.user).to eq(user)
    expect(persisted.messages.first.user).to eq(user)
  end

  it "attaches a cover image file" do
    file = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")

    post "/graphql",
      params: {
        operations: {
          query: query,
          variables: {
            title: "With Upload",
            recipient: "Bob",
            text: "Thinking of you",
            coverImageFile: nil # placeholder for map
          }
        }.to_json,
        map: { "0" => [ "variables.coverImageFile" ] }.to_json,
        "0" => file
      },
      headers: headers.merge("Content-Type" => "multipart/form-data")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createOneOnOneCard")
    expect(data["errors"]).to be_empty
    expect(data["card"]).to be_present
    expect(Card.last.cover_image).to be_attached
  end

  it "rolls back both card and message on validation failure" do
    expect {
      post_query(
        title: "", # invalid: title is required
        recipient: "Sam",
        text: "Hello"
      )
    }.to change(Card, :count).by(0).and change(Message, :count).by(0)

    json = JSON.parse(response.body)
    data = json.dig("data", "createOneOnOneCard")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to include("Title can't be blank")
  end

  it "requires authentication and creates nothing" do
    expect {
      post "/graphql",
        params: {
          operationName: "CreateOneOnOneCard",
          query: query,
          variables: {
            title: "For You",
            recipient: "Sam",
            text: "Hi"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" } # no Authorization header
    }.to change(Card, :count).by(0).and change(Message, :count).by(0)

    json = JSON.parse(response.body)
    data = json.dig("data", "createOneOnOneCard")
    expect(data["card"]).to be_nil
    expect(data["errors"]).to eq([ "Not authenticated" ])
  end
end
