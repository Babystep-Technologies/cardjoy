# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvitationDraft do
  describe '.new' do
    let(:user) { create(:user) }

    it 'creates a draft with defaults' do
      draft = described_class.new
      expect(draft.external_id).to be_present
      expect(draft.status).to eq('pending')
      expect(draft.created_at).to be_present
      expect(draft.updated_at).to be_present
    end

    it 'accepts all parameters' do
      payload = { 'title' => 'Test' }
      draft = described_class.new(
        external_id: 'custom-id',
        preview_title: 'Birthday Party',
        preview_message: 'Join us!',
        preview_event_date: Date.new(2026, 1, 15),
        preview_event_time: '19:00',
        preview_location: 'My House',
        ai_payload: payload,
        status: 'approved',
        user: user
      )

      expect(draft.external_id).to eq('custom-id')
      expect(draft.preview_title).to eq('Birthday Party')
      expect(draft.preview_message).to eq('Join us!')
      expect(draft.preview_event_date).to eq(Date.new(2026, 1, 15))
      expect(draft.preview_event_time).to eq('19:00')
      expect(draft.preview_location).to eq('My House')
      expect(draft.ai_payload).to eq(payload)
      expect(draft.status).to eq('approved')
      expect(draft.user).to eq(user)
    end

    it 'generates unique external_ids' do
      draft1 = described_class.new
      draft2 = described_class.new
      expect(draft1.external_id).not_to eq(draft2.external_id)
    end

    it 'allows overriding external_id' do
      custom_id = 'my-custom-id'
      draft = described_class.new(external_id: custom_id)
      expect(draft.external_id).to eq(custom_id)
    end

    it 'defaults status to pending' do
      draft = described_class.new
      expect(draft.status).to eq('pending')
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      user = create(:user)
      draft = described_class.new(
        external_id: 'test-id',
        preview_title: 'Party',
        preview_location: 'Park',
        user: user
      )

      hash = draft.to_h
      expect(hash).to include(
        external_id: 'test-id',
        preview_title: 'Party',
        preview_location: 'Park',
        status: 'pending'
      )
      expect(hash.keys).to include(:created_at, :updated_at)
    end

    it 'excludes user from hash output' do
      user = create(:user)
      draft = described_class.new(user: user)
      hash = draft.to_h
      expect(hash).not_to include(:user)
    end
  end
end
