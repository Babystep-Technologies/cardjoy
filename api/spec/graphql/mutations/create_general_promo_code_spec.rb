# typed: false

require 'rails_helper'
require 'jwt'

RSpec.describe Mutations::CreateGeneralPromoCode, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:admin_token) { JWT.encode({ admin_id: admin.id }, secret, 'HS256') }
  let(:user_token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }

  let(:admin_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{admin_token}" }
  end
  let(:user_headers) do
    { 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{user_token}" }
  end

  let(:mutation) do
    <<~GQL
      mutation CreateGeneralPromoCode($usageLimit: Int!, $code: String, $expiresAt: ISO8601DateTime) {
        createGeneralPromoCode(input: { usageLimit: $usageLimit, code: $code, expiresAt: $expiresAt }) {
          promoCode { code creditAmount usageLimit user { email } }
          errors
        }
      }
    GQL
  end

  def create_code(variables:, headers: admin_headers)
    post '/graphql', params: { query: mutation, variables: variables }.to_json, headers: headers
  end

  context 'when an admin creates a general code' do
    it 'creates a global code worth 1 credit with the given cap' do
      expect {
        create_code(variables: { usageLimit: 500, code: 'WELCOME2026' })
      }.to change { PromoCode.count }.by(1)

      data = JSON.parse(response.body)['data']['createGeneralPromoCode']
      expect(data['errors']).to be_empty
      expect(data['promoCode']['creditAmount']).to eq 1
      expect(data['promoCode']['usageLimit']).to eq 500
      expect(data['promoCode']['user']).to be_nil

      promo = PromoCode.last
      expect(promo.user_id).to be_nil
      expect(promo.code).to eq 'welcome2026'
    end

    it 'auto-generates a code when none is supplied' do
      create_code(variables: { usageLimit: 10 })
      expect(PromoCode.last.code).to match(/\Acj-[a-z0-9]{8}\z/)
    end
  end

  context 'when the code already exists' do
    before { create(:promo_code, code: 'welcome2026') }

    it 'returns a validation error' do
      create_code(variables: { usageLimit: 10, code: 'WELCOME2026' })
      data = JSON.parse(response.body)['data']['createGeneralPromoCode']
      expect(data['promoCode']).to be_nil
      expect(data['errors'].join).to match(/already been taken/i)
    end
  end

  context 'when the requester is not an admin' do
    it 'returns a not authorized error' do
      create_code(variables: { usageLimit: 10 }, headers: user_headers)
      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Not authorized'
    end
  end
end
