# typed: false

require 'rails_helper'
require 'jwt'

RSpec.describe Mutations::IssueUserPromoCode, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user, email: 'recipient@example.com') }
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
      mutation IssueUserPromoCode($email: String!, $creditAmount: Int!, $code: String, $expiresAt: ISO8601DateTime) {
        issueUserPromoCode(input: { email: $email, creditAmount: $creditAmount, code: $code, expiresAt: $expiresAt }) {
          promoCode { code creditAmount usageLimit timesRedeemed user { email } }
          errors
        }
      }
    GQL
  end

  def issue(variables:, headers: admin_headers)
    post '/graphql', params: { query: mutation, variables: variables }.to_json, headers: headers
  end

  context 'when an admin issues a code to an existing user' do
    it 'creates a user-specific promo code with usage_limit 1' do
      expect {
        issue(variables: { email: user.email, creditAmount: 25 })
      }.to change { PromoCode.count }.by(1)

      data = JSON.parse(response.body)['data']['issueUserPromoCode']
      expect(data['errors']).to be_empty
      expect(data['promoCode']['creditAmount']).to eq 25
      expect(data['promoCode']['usageLimit']).to eq 1
      expect(data['promoCode']['user']['email']).to eq user.email

      promo = PromoCode.last
      expect(promo.user_id).to eq user.id
      expect(promo.code).to be_present
    end

    it 'downcases an admin-provided code' do
      issue(variables: { email: user.email, creditAmount: 5, code: 'WELCOME-JANE' })
      expect(PromoCode.last.code).to eq 'welcome-jane'
    end

    it 'auto-generates a code when none is supplied' do
      issue(variables: { email: user.email, creditAmount: 5 })
      expect(PromoCode.last.code).to match(/\Acj-[a-z0-9]{8}\z/)
    end

    it 'emails the recipient about the issued code' do
      expect {
        issue(variables: { email: user.email, creditAmount: 25 })
      }.to have_enqueued_mail(UserMailer, :promo_code_issued)
    end
  end

  context 'when the user does not exist' do
    it 'returns a "User not found" error and creates nothing' do
      expect {
        issue(variables: { email: 'nobody@example.com', creditAmount: 25 })
      }.not_to change { PromoCode.count }

      data = JSON.parse(response.body)['data']['issueUserPromoCode']
      expect(data['promoCode']).to be_nil
      expect(data['errors']).to include('User not found')
    end
  end

  context 'when the code already exists' do
    before { create(:promo_code, code: 'dupe') }

    it 'returns a validation error' do
      issue(variables: { email: user.email, creditAmount: 25, code: 'DUPE' })
      data = JSON.parse(response.body)['data']['issueUserPromoCode']
      expect(data['promoCode']).to be_nil
      expect(data['errors'].join).to match(/already been taken/i)
    end
  end

  context 'when the requester is not an admin' do
    it 'returns a not authorized error' do
      issue(variables: { email: user.email, creditAmount: 25 }, headers: user_headers)
      expect(JSON.parse(response.body)['errors'].first['message']).to eq 'Not authorized'
    end
  end
end
