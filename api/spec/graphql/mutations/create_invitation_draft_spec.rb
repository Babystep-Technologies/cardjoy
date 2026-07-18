# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::CreateInvitationDraft, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:mutation) do
    <<~GQL
      mutation CreateInvitationDraft(
        $input: CreateInvitationDraftInput!
      ) {
        createInvitationDraft(input: $input) {
          draft {
            externalId
            previewTitle
            previewMessage
            previewEventDate
            previewEventTime
            previewLocation
            status
            aiPayload
            createdAt
          }
          errors
        }
      }
    GQL
  end

  describe 'happy path: generate draft via AI stub' do
    it 'creates a transient draft with AI-generated content' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Birthday Celebration',
              previewMessage: 'You are invited to a birthday party!',
              previewEventDate: '2024-12-01',
              previewEventTime: '19:00',
              previewLocation: '123 Party St, Fun City',
              prompt: 'Birthday celebration next weekend'
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)

      expect(json['errors']).to be_nil
      draft = json.dig('data', 'createInvitationDraft', 'draft')

      expect(draft).to be_present
      expect(draft['externalId']).to be_present
      expect(draft['previewTitle']).to include('invited')
      expect(draft['previewMessage']).to include('Birthday celebration')
      expect(draft['status']).to eq('pending')
      expect(draft['aiPayload']).to be_present
      expect(draft['aiPayload']['prompt']).to eq('Birthday celebration next weekend')
    end
  end

  describe 'happy path: create draft from explicit payload' do
    it 'accepts explicit preview fields and ai_payload' do
      ai_payload = {
        'generated_at' => Time.current.iso8601,
        'model' => 'test-model',
        'content' => { 'title' => 'Test' }
      }

      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Wedding Celebration',
              previewMessage: 'You are cordially invited',
              previewEventDate: '2026-06-15',
              previewEventTime: '18:00',
              previewLocation: 'The Garden Hotel',
              aiPayload: ai_payload
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      expect(json['errors']).to be_nil
      draft = json.dig('data', 'createInvitationDraft', 'draft')

      expect(draft['previewTitle']).to eq('Wedding Celebration')
      expect(draft['previewMessage']).to eq('You are cordially invited')
      expect(draft['previewEventDate']).to eq('2026-06-15')
      expect(draft['previewEventTime']).to eq('18:00')
      expect(draft['previewLocation']).to eq('The Garden Hotel')
    end
  end

  describe 'credit deduction' do
    it 'does not deduct a credit for a transient draft' do
      expect do
        post '/graphql',
          params: {
            query: mutation,
            variables: {
              input: {
                previewTitle: 'Wedding Celebration',
                previewEventDate: '2026-06-15',
                previewEventTime: '18:00',
                aiPayload: { 'content' => { 'title' => 'Test' } }
              }
            }
          }.to_json,
          headers: headers
      end.not_to change { user.reload.credit_balance }
    end
  end

  describe 'error handling' do
    it 'returns error when not signed in' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              externalId: SecureRandom.uuid,
              previewTitle: 'Birthday Celebration',
              previewMessage: 'You are invited to a birthday party!',
              previewEventDate: '2024-12-01',
              previewEventTime: '19:00',
              previewLocation: '123 Party St, Fun City',
              prompt: 'Test'
            }
          }
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }

      json = JSON.parse(response.body)
      expect(json['errors']).to include("Unauthorized")
    end
  end
end
