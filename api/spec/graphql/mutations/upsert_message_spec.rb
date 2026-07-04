require 'rails_helper'
require 'jwt'

RSpec.describe Mutations::UpsertMessage, type: :request do
  let(:card) { create(:card) }
  let(:user) { create(:user) }

  let(:query) do
    <<~GRAPHQL
      mutation UpsertMessage(
        $cardId: ID!,
        $title: String,
        $text: String!,
        $userId: ID,
        $guestName: String,
        $imageUrl: String,
        $displayName: String
      ) {
        upsertMessage(
          input: {
            cardId: $cardId,
            title: $title,
            text: $text,
            userId: $userId,
            guestName: $guestName,
            imageUrl: $imageUrl,
            displayName: $displayName
          }
        ) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def run_mutation(variables)
    post '/graphql', params: { query: query, variables: variables, operationName: "UpsertMessage" }.to_json, headers: { 'Content-Type': 'application/json' }
  end

  context "with user_id and remote image_url" do
    it "creates a message and attaches image from URL" do
      stub_image_url = "https://placehold.co/600x400.gif"
      stub_request(:get, stub_image_url).to_return(status: 200, body: "GIF89a", headers: { "Content-Type" => "image/gif" })
      run_mutation({
        cardId: card.external_id,
        userId: user.id,
        title: "Hello!",
        text: "This is a test",
        imageUrl: stub_image_url
      })

      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")

      expect(data["success"]).to be true
      expect(data["errors"]).to be_empty

      message = Message.find_by(user_id: user.id)
      expect(message).not_to be_nil
      expect(message.image).to be_attached
    end

    it "creates a message without a title" do
      run_mutation({
        cardId: card.external_id,
        userId: user.id,
        text: "No title message"
      })
      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")
      expect(data["success"]).to be true
      expect(data["errors"]).to be_empty
      message = Message.find_by(user_id: user.id)
      expect(message).not_to be_nil
      expect(message.title).to be_nil
    end

    it "creates a message with custom display name" do
      run_mutation({
        cardId: card.external_id,
        userId: user.id,
        text: "Message with custom display name",
        displayName: "Custom Display Name"
      })
      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")
      expect(data["success"]).to be true
      expect(data["errors"]).to be_empty
      message = Message.find_by(user_id: user.id)
      expect(message).not_to be_nil
      expect(message.display_name).to eq("Custom Display Name")
    end

    it "creates a message without display name" do
      run_mutation({
        cardId: card.external_id,
        userId: user.id,
        text: "Message without display name"
      })
      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")
      expect(data["success"]).to be true
      expect(data["errors"]).to be_empty
      message = Message.find_by(user_id: user.id)
      expect(message).not_to be_nil
      expect(message.display_name).to be_nil
    end
  end

  context "with guest_name and uploaded file" do
    it "creates a guest message with attached file" do
      file = fixture_file_upload(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg")

      query = <<~GRAPHQL
				mutation UpsertMessage($input: UpsertMessageInput!) {
					upsertMessage(input: $input) {
						success
						errors
					}
				}
      GRAPHQL

      operations = {
        query: query,
        operationName: "UpsertMessage",
        variables: {
          input: {
            cardId: card.external_id,
            guestName: "Guesty",
            title: "Hi!",
            text: "With file upload",
            file: nil # important: file must be null here
          }
        }
      }

      map = {
        "0" => [ "variables.input.file" ]
      }

      post "/graphql",
        params: {
          operations: operations.to_json,
          map: map.to_json,
          "0" => file
        },
        headers: {
          "Content-Type" => "multipart/form-data"
        }

      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")

      expect(data["success"]).to be true
      expect(data["errors"]).to be_empty

      guest_message = GuestMessage.find_by(name: "Guesty")
      expect(guest_message).not_to be_nil
      expect(guest_message.image).to be_attached
    end
  end

  context "when card is locked" do
    it "returns error" do
      card.lock!

      run_mutation({
        cardId: card.external_id,
        userId: user.id,
        title: "Locked",
        text: "Should fail"
      })

      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")

      expect(data["success"]).to be false
      expect(data["errors"]).to include("Card is locked and cannot receive more messages")
    end
  end

  context "without user_id or guest_name" do
    it "returns an auth error" do
      run_mutation({
        cardId: card.external_id,
        title: "Anonymous",
        text: "Missing auth"
      })

      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")

      expect(data["success"]).to be false
      expect(data["errors"]).to include("Authentication or guest name required")
    end
  end

  context "when card has reached max messages" do
    it "prevents new guest message if over the limit" do
      card.update!(max_messages: 2)
      create_list(:message, 1, card: card)
      create_list(:guest_message, 1, card: card)

      run_mutation({
        cardId: card.external_id,
        guestName: "Guest Overflow",
        title: "Too late",
        text: "Should not be allowed"
      })

      json = JSON.parse(response.body)
      data = json.dig("data", "upsertMessage")

      expect(data["success"]).to be false
      expect(data["errors"]).to include("This card has reached its maximum number of messages.")
    end
  end
end
