# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mutations::ApproveInvitationDraft, type: :request do
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
      mutation ApproveInvitationDraft(
        $input: ApproveInvitationDraftInput!
      ) {
        approveInvitationDraft(input: $input) {
          invitation {
            id
            externalId
            title
            description
            location
            eventDate
            eventTime
          }
          errors
        }
      }
    GQL
  end

  describe 'happy path: approve draft and create invitation' do
    it 'creates a persisted invitation from draft data' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Birthday Party',
              previewMessage: 'Join us for cake!',
              previewEventDate: '2026-01-20',
              previewEventTime: '19:00',
              previewLocation: 'My House'
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      expect(json['errors']).to be_nil
      invitation = json.dig('data', 'approveInvitationDraft', 'invitation')

      expect(invitation).to be_present
      expect(invitation['title']).to eq('Birthday Party')
      expect(invitation['description']).to eq('Join us for cake!')
      expect(invitation['location']).to eq('My House')
      expect(invitation['eventDate']).to eq('2026-01-20')
      expect(invitation['eventTime']).to eq('19:00')
      expect(invitation['externalId']).to be_present
    end

    it 'extracts fields from ai_payload if not explicitly provided' do
      ai_payload = {
        'content' => {
          'title' => 'AI Generated Title',
          'message' => 'AI Generated Message',
          'event_date' => '2026-02-14',
          'event_time' => '20:00',
          'location' => 'Downtown Venue'
        }
      }

      post '/graphql',
        params: {
          query: mutation,
          variables: { input: { aiPayload: ai_payload } }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      expect(json['errors']).to be_nil
      invitation = json.dig('data', 'approveInvitationDraft', 'invitation')

      expect(invitation['title']).to eq('AI Generated Title')
      expect(invitation['description']).to eq('AI Generated Message')
      expect(invitation['location']).to eq('Downtown Venue')
      expect(invitation['eventDate']).to eq('2026-02-14')
      expect(invitation['eventTime']).to eq('20:00')
    end
  end

  describe 'error handling' do
    it 'returns error when title is missing' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewEventDate: '2026-01-20',
              previewEventTime: '19:00'
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      errors = json.dig('data', 'approveInvitationDraft', 'errors')
      expect(errors).to include('Title is required')
    end

    it 'returns error when event_date is missing' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Party',
              previewEventTime: '19:00'
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      errors = json.dig('data', 'approveInvitationDraft', 'errors')
      expect(errors).to include('Event date is required')
    end

    it 'returns error when event_time is missing' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Party',
              previewEventDate: '2026-01-20'
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      errors = json.dig('data', 'approveInvitationDraft', 'errors')
      expect(errors).to include('Event time is required')
    end

    it 'returns error for invalid event_time format' do
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Party',
              previewEventDate: '2026-01-20',
              previewEventTime: 'not-a-time'
            }
          }
        }.to_json,
        headers: headers

      json = JSON.parse(response.body)
      errors = json.dig('data', 'approveInvitationDraft', 'errors')
      expect(errors).to include('Event time must be parseable')
    end
  end

  describe 'persistence' do
    it 'creates a real Invitation record in the database' do
      expect {
        post '/graphql',
          params: {
            query: mutation,
            variables: {
              input: {
                previewTitle: 'Database Test',
                previewEventDate: '2026-03-15',
                previewEventTime: '15:00'
              }
            }
          }.to_json,
          headers: headers
      }.to change(Invitation, :count).by(1)

      invitation = Invitation.last
      expect(invitation.title).to eq('Database Test')
      expect(invitation.user_id).to eq(user.id)
    end
  end

  describe 'credit deduction' do
    def approve_draft
      post '/graphql',
        params: {
          query: mutation,
          variables: {
            input: {
              previewTitle: 'Birthday Party',
              previewEventDate: '2026-01-20',
              previewEventTime: '19:00'
            }
          }
        }.to_json,
        headers: headers
      JSON.parse(response.body).dig('data', 'approveInvitationDraft')
    end

    it 'deducts exactly one credit on success' do
      expect { approve_draft }.to change { user.reload.credit_balance }.by(-1)

      debit = user.credits.order(:id).last
      expect(debit.amount).to eq(-1)
      expect(debit.events.first['event_kind']).to eq('invitation_created')
    end

    it 'blocks the create and charges nothing when the balance is empty' do
      user.credits.destroy_all
      invitation_count = Invitation.count
      credit_count = Credit.count

      result = approve_draft

      expect(result['invitation']).to be_nil
      expect(result['errors']).to include('Not enough credits')
      expect(Invitation.count).to eq(invitation_count)
      expect(Credit.count).to eq(credit_count)
    end
  end
end
