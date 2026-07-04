require 'rails_helper'

RSpec.describe 'Mutations::ReactToMessage', type: :request do
  let(:user) { create(:user) }
  let(:card) { create(:card) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:mutation) do
    <<~GQL
      mutation ReactToMessage($messageId: ID!, $messageType: String!) {
        reactToMessage(input: { messageId: $messageId, messageType: $messageType }) {
          success
          errors
          messageId
          messageType
        }
      }
    GQL
  end

  shared_examples 'a reactable message' do
    it 'adds user ID to reacted_user_ids if not present' do
      post '/graphql', params: {
        query: mutation,
        variables: {
          messageId: message_obj.id,
          messageType: message_type
        }
      }.to_json, headers: headers

      message_obj.reload
      data = JSON.parse(response.body)['data']['reactToMessage']

      expect(response).to have_http_status(:ok)
      expect(data['success']).to eq(true)
      expect(message_obj.details['reacted_user_ids'].map(&:to_s)).to include(user.id.to_s)
    end

    it 'removes user ID if already present' do
      message_obj.update!(details: { reacted_user_ids: [ user.id ] })

      post '/graphql', params: {
        query: mutation,
        variables: {
          messageId: message_obj.id,
          messageType: message_type
        }
      }.to_json, headers: headers

      message_obj.reload
      data = JSON.parse(response.body)['data']['reactToMessage']

      expect(response).to have_http_status(:ok)
      expect(data['success']).to eq(true)
      expect(message_obj.details['reacted_user_ids'].map(&:to_s)).not_to include(user.id.to_s)
    end

    it 'returns error for nonexistent message' do
      post '/graphql', params: {
        query: mutation,
        variables: {
          messageId: 'nonexistent',
          messageType: message_type
        }
      }.to_json, headers: headers

      data = JSON.parse(response.body)['data']['reactToMessage']
      expect(data['success']).to eq(false)
      expect(data['errors']).to be_present
    end
  end

  describe 'Reacting to a Message' do
    let!(:message_obj) { create(:message, card: card, user: user, details: { reacted_user_ids: [] }) }
    let(:message_type) { 'Message' }

    it_behaves_like 'a reactable message'
  end

  describe 'Reacting to a GuestMessage' do
    let!(:message_obj) { create(:guest_message, card: card, details: { reacted_user_ids: [] }) }
    let(:message_type) { 'GuestMessage' }

    it_behaves_like 'a reactable message'
  end
end
