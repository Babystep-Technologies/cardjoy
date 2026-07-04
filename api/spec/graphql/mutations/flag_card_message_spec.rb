require 'rails_helper'
require 'jwt'

RSpec.describe Mutations::FlagCardMessage, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:card_owner) { create(:user) }
  let(:card) { create(:card, user: card_owner) }
  let(:other_user_card) { create(:card, user: user) }
  let(:message) { create(:message, card: card) }
  let(:guest_message) { create(:guest_message, card: card) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:admin_token) do
    JWT.encode({ admin_id: admin.id }, secret, 'HS256')
  end

  let(:user_token) do
    JWT.encode({ user_id: user.id }, secret, 'HS256')
  end

  let(:card_owner_token) do
    JWT.encode({ user_id: card_owner.id }, secret, 'HS256')
  end

  let(:admin_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{admin_token}"
    }
  end

  let(:user_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{user_token}"
    }
  end

  let(:card_owner_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{card_owner_token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation FlagCardMessage($input: FlagCardMessageInput!) {
        flagCardMessage(input: $input) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def execute_mutation(message_id:, message_kind:, headers: admin_headers)
    post '/graphql',
      params: {
        query: query,
        variables: {
          input: {
            messageId: message_id,
            messageKind: message_kind
          }
        }
      }.to_json,
      headers: headers
  end

  describe 'when admin is authenticated' do
    context 'with a user message' do
      it 'flags an unflagged message successfully' do
        expect(message.flagged?).to be false

        execute_mutation(message_id: message.id, message_kind: 'user')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(message.reload.flagged?).to be true
      end

      it 'unflags a flagged message successfully' do
        message.flag!
        expect(message.flagged?).to be true

        execute_mutation(message_id: message.id, message_kind: 'user')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(message.reload.flagged?).to be false
      end

      it 'returns error if message not found' do
        execute_mutation(message_id: 99999, message_kind: 'user')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be false
        expect(data['errors']).to include('Message not found')
      end
    end

    context 'with a guest message' do
      it 'flags an unflagged guest message successfully' do
        expect(guest_message.flagged?).to be false

        execute_mutation(message_id: guest_message.id, message_kind: 'guest')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(guest_message.reload.flagged?).to be true
      end

      it 'unflags a flagged guest message successfully' do
        guest_message.flag!
        expect(guest_message.flagged?).to be true

        execute_mutation(message_id: guest_message.id, message_kind: 'guest')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(guest_message.reload.flagged?).to be false
      end

      it 'returns error if guest message not found' do
        execute_mutation(message_id: 99999, message_kind: 'guest')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be false
        expect(data['errors']).to include('Message not found')
      end
    end

    context 'with invalid message kind' do
      it 'returns error for invalid message kind' do
        execute_mutation(message_id: message.id, message_kind: 'invalid')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be false
        expect(data['errors']).to include('Invalid message kind')
      end
    end
  end

  describe 'when card owner is authenticated' do
    context 'with a user message on their own card' do
      it 'flags an unflagged message successfully' do
        expect(message.flagged?).to be false

        execute_mutation(
          message_id: message.id,
          message_kind: 'user',
          headers: card_owner_headers
        )

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(message.reload.flagged?).to be true
      end

      it 'unflags a flagged message successfully' do
        message.flag!
        expect(message.flagged?).to be true

        execute_mutation(
          message_id: message.id,
          message_kind: 'user',
          headers: card_owner_headers
        )

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(message.reload.flagged?).to be false
      end
    end

    context 'with a guest message on their own card' do
      it 'flags an unflagged guest message successfully' do
        expect(guest_message.flagged?).to be false

        execute_mutation(
          message_id: guest_message.id,
          message_kind: 'guest',
          headers: card_owner_headers
        )

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(guest_message.reload.flagged?).to be true
      end
    end
  end

  describe 'when regular user is authenticated' do
    let(:other_user_message) { create(:message, card: other_user_card) }

    context 'trying to flag a message on someone else\'s card' do
      it 'returns unauthorized error' do
        execute_mutation(
          message_id: message.id,
          message_kind: 'user',
          headers: user_headers
        )

        json = JSON.parse(response.body)
        error = json['errors'].first['message']

        expect(error).to eq('Not authorized')
      end
    end

    context 'trying to flag a message on their own card' do
      it 'allows card owner to flag messages on their own card' do
        user_message = create(:message, card: other_user_card)
        expect(user_message.flagged?).to be false

        execute_mutation(
          message_id: user_message.id,
          message_kind: 'user',
          headers: user_headers
        )

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be true
        expect(data['errors']).to be_empty
        expect(user_message.reload.flagged?).to be true
      end
    end
  end

  describe 'when not authenticated' do
    it 'returns unauthorized error' do
      execute_mutation(
        message_id: message.id,
        message_kind: 'user',
        headers: { 'Content-Type' => 'application/json' }
      )

      json = JSON.parse(response.body)
      error = json['errors'].first

      expect(error).to eq('Unauthorized')
    end
  end

  describe 'error handling' do
    context 'when flagging fails' do
      it 'handles exceptions and returns error' do
        # Simulate an error by stubbing the flag! method
        allow_any_instance_of(Message).to receive(:flag!).and_raise(StandardError.new('Database error'))

        execute_mutation(message_id: message.id, message_kind: 'user')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be false
        expect(data['errors']).to include('Database error')
      end
    end

    context 'when unflagging fails' do
      it 'handles exceptions and returns error' do
        message.flag!

        # Simulate an error by stubbing the unflag! method
        allow_any_instance_of(Message).to receive(:unflag!).and_raise(StandardError.new('Database error'))

        execute_mutation(message_id: message.id, message_kind: 'user')

        json = JSON.parse(response.body)
        data = json.dig('data', 'flagCardMessage')

        expect(data['success']).to be false
        expect(data['errors']).to include('Database error')
      end
    end
  end
end
