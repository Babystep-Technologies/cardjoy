# typed: false

require 'rails_helper'

RSpec.describe "Mutations::RedeemPromoCode", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:other_token) { JWT.encode({ user_id: other_user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end
  let(:other_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{other_token}"
    }
  end

  let(:mutation) do
    <<~GQL
      mutation RedeemPromoCode($code: String!) {
        redeemPromoCode(input: { code: $code }) {
          success
          creditAmount
          error
        }
      }
    GQL
  end

  describe 'general promo codes (no user_id)' do
    let!(:promo_code) do
      create(:promo_code,
        code: 'GENERAL10'.downcase,
        credit_amount: 10,
        expires_at: 1.week.from_now,
        usage_limit: 100,
        times_redeemed: 0,
        user_id: nil
      )
    end

    context 'when valid promo code is provided' do
      it 'successfully redeems the promo code' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'GENERAL10' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']['redeemPromoCode']

        expect(data['success']).to be true
        expect(data['creditAmount']).to eq 10
        expect(data['error']).to be_nil

        # Check that redemption was recorded
        expect(PromoCodeRedemption.exists?(user: user, promo_code: promo_code)).to be true
        expect(promo_code.reload.times_redeemed).to eq 1

        # Check that credit was issued
        credit = user.credits.last
        expect(credit.amount).to eq 10
        expect(credit.reason).to eq 'promotion'
      end

      it 'handles case insensitive codes' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'general10' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']['redeemPromoCode']
        expect(data['success']).to be true
      end

      it 'handles codes with whitespace' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: ' GENERAL10 ' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']['redeemPromoCode']
        expect(data['success']).to be true
      end
    end

    context 'when user is not authenticated' do
      it 'returns authentication error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'GENERAL10' }
        }.to_json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when promo code does not exist' do
      it 'returns invalid promo code error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'INVALID' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']
        expect(data["success"]).to be false
        expect(data["error"]).to eq "Invalid promo code"
      end
    end

    context 'when promo code has expired' do
      before { promo_code.update!(expires_at: 1.week.ago) }

      it 'returns expired error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'GENERAL10' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']
        expect(data["success"]).to be false
        expect(data["error"]).to eq "Promo code has expired"
      end
    end

    context 'when promo code has reached usage limit' do
      before { promo_code.update!(times_redeemed: 100, usage_limit: 100) }

      it 'returns limit reached error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'GENERAL10' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']
        expect(data["success"]).to be false
        expect(data["error"]).to eq "Promo code has reached its limit"
      end
    end

    context 'when user has already redeemed the promo code' do
      before { create(:promo_code_redemption, user: user, promo_code: promo_code) }

      it 'returns already redeemed error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'GENERAL10' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        data = json_response['data']['redeemPromoCode']
        expect(data["success"]).to be false
        expect(data["error"]).to eq "You've already redeemed this promo code"
      end
    end
  end

  describe 'user-specific promo codes' do
    let!(:user_specific_promo) do
      create(:promo_code,
        code: 'USER_SPECIFIC_20'.downcase,
        credit_amount: 20,
        expires_at: 1.week.from_now,
        usage_limit: 1,
        times_redeemed: 0,
        user_id: user.id
      )
    end

    context 'when the assigned user redeems the code' do
      it 'successfully redeems the promo code' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'USER_SPECIFIC_20' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']['redeemPromoCode']

        expect(data['success']).to be true
        expect(data['creditAmount']).to eq 20
        expect(data['error']).to be_nil

        # Check that redemption was recorded
        expect(PromoCodeRedemption.exists?(user: user, promo_code: user_specific_promo)).to be true
        expect(user_specific_promo.reload.times_redeemed).to eq 1

        # Check that credit was issued
        credit = user.credits.last
        expect(credit.amount).to eq 20
        expect(credit.reason).to eq 'promotion'
      end
    end

    context 'when a different user tries to redeem the code' do
      it 'returns not available error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'USER_SPECIFIC_20' }
        }.to_json, headers: other_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']
        expect(data['success']).to be false
        expect(data['error']).to eq "This promo code is not available for your account"
      end

      it 'does not create a redemption record' do
        expect {
          post '/graphql', params: {
            query: mutation,
            variables: { code: 'USER_SPECIFIC_20' }
          }.to_json, headers: other_headers
        }.not_to change { PromoCodeRedemption.count }
      end

      it 'does not increment times_redeemed' do
        expect {
          post '/graphql', params: {
            query: mutation,
            variables: { code: 'USER_SPECIFIC_20' }
          }.to_json, headers: other_headers
        }.not_to change { user_specific_promo.reload.times_redeemed }
      end

      it 'does not issue credits' do
        expect {
          post '/graphql', params: {
            query: mutation,
            variables: { code: 'USER_SPECIFIC_20' }
          }.to_json, headers: other_headers
        }.not_to change { other_user.credits.count }
      end
    end
  end

  describe 'edge cases with user-specific promo codes' do
    context 'when user-specific promo code has expired' do
      let!(:expired_user_promo) do
        create(:promo_code,
          code: 'EXPIRED_USER'.downcase,
          credit_amount: 15,
          expires_at: 1.week.ago,
          user_id: user.id,
          usage_limit: 1,
        )
      end

      it 'returns expired error for the assigned user' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'EXPIRED_USER' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']

        expect(data['success']).to be false
        expect(data['error']).to eq "Promo code has expired"
      end

      it 'returns not available error for other users' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'EXPIRED_USER' }
        }.to_json, headers: other_headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']
        expect(data['success']).to be false
        expect(data['error']).to eq "This promo code is not available for your account"
      end
    end

    context 'when user-specific promo code has already been redeemed' do
      let!(:redeemed_user_promo) do
        create(:promo_code,
          code: 'REDEEMED_USER'.downcase,
          credit_amount: 25,
          expires_at: 1.week.from_now,
          usage_limit: 1,
          times_redeemed: 0,
          user_id: user.id
        )
      end

      before { create(:promo_code_redemption, user: user, promo_code: redeemed_user_promo) }

      it 'returns already redeemed error' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'REDEEMED_USER' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        data = json_response['data']['redeemPromoCode']
        expect(data['success']).to be false
        expect(data['error']).to eq "You've already redeemed this promo code"
      end
    end
  end

  describe 'error handling' do
    let!(:promo_code) { create(:promo_code, code: 'ERROR_TEST'.downcase, credit_amount: 5) }

    context 'when an unexpected error occurs' do
      before do
        allow(PromoCodeRedemption).to receive(:create!).and_raise(StandardError, 'Database error')
      end

      it 'returns success false with error message' do
        post '/graphql', params: {
          query: mutation,
          variables: { code: 'ERROR_TEST' }
        }.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)['data']['redeemPromoCode']

        expect(data['success']).to be false
        expect(data['error']).to eq 'Database error'
        expect(data['creditAmount']).to be_nil
      end
    end
  end
end
