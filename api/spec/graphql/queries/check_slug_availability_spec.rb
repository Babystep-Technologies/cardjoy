require 'rails_helper'

RSpec.describe 'CheckSlugAvailability', type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      query CheckSlugAvailability($slug: String!, $type: String!, $currentId: String) {
        checkSlugAvailability(slug: $slug, type: $type, currentId: $currentId)
      }
    GRAPHQL
  end

  def exec_query(variables)
    post '/graphql',
      params: { query: query, variables: variables }.to_json,
      headers: headers
  end

  describe 'card slugs' do
    it 'returns true when slug is available' do
      exec_query(slug: 'my-birthday-card', type: 'card')
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be true
    end

    it 'returns false when slug is already taken' do
      create(:card, user: user, slug: 'taken-slug')
      exec_query(slug: 'taken-slug', type: 'card')
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be false
    end

    it 'returns true when slug belongs to current card being edited' do
      card = create(:card, user: user, slug: 'my-slug')
      exec_query(slug: 'my-slug', type: 'card', currentId: card.external_id)
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be true
    end
  end

  describe 'invitation slugs' do
    it 'returns true when slug is available' do
      exec_query(slug: 'emmas-birthday', type: 'invitation')
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be true
    end

    it 'returns false when slug is already taken' do
      create(:invitation, user: user, slug: 'taken-party')
      exec_query(slug: 'taken-party', type: 'invitation')
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be false
    end

    it 'returns true when slug belongs to current invitation being edited' do
      invitation = create(:invitation, user: user, slug: 'my-party')
      exec_query(slug: 'my-party', type: 'invitation', currentId: invitation.external_id)
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be true
    end
  end

  describe 'empty slug' do
    it 'returns true for empty slug' do
      exec_query(slug: '', type: 'card')
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'checkSlugAvailability')).to be true
    end
  end
end
