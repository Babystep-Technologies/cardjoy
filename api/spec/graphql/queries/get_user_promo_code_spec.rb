require 'rails_helper'

RSpec.describe 'GetUserPromoCode', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) do
    JWT.encode({ user_id: user.id }, secret, 'HS256')
  end
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      query GetUserPromoCode($userId: ID!) {
        userPromoCode(userId: $userId) {
          code
          creditAmount
          user { id }
        }
      }
    GRAPHQL
  end

  def exec_query
    post '/graphql', params: {
      query: query,
      variables: { userId: user.id }
    }.to_json,
    headers: headers
  end

  describe 'when no promo codes exist' do
    it 'returns nil if there are no promo codes' do
      exec_query
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'userPromoCode')).to be_nil
    end
  end

  describe 'general promo codes (user_id: nil)' do
    it 'skips promo codes that are expired' do
      create(:promo_code, expires_at: 1.day.ago, user_id: nil)
      exec_query
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'userPromoCode')).to be_nil
    end

    it 'skips promo codes that have reached usage limit' do
      create(:promo_code, usage_limit: 5, times_redeemed: 5, expires_at: nil, user_id: nil)
      exec_query
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'userPromoCode')).to be_nil
    end

    it 'skips promo codes already redeemed by user' do
      promo = create(:promo_code, usage_limit: 5, times_redeemed: 4, expires_at: nil, user_id: nil)
      create(:promo_code_redemption, user: user, promo_code: promo)
      exec_query
      json_response = JSON.parse(response.body)
      expect(json_response.dig('data', 'userPromoCode')).to be_nil
    end

    it 'returns a valid general promo code' do
      promo = create(:promo_code, credit_amount: 10, usage_limit: 5, times_redeemed: 2, expires_at: nil, user_id: nil)
      exec_query
      json_response = JSON.parse(response.body)
      data = json_response.dig('data', 'userPromoCode')
      expect(data['code']).to eq(promo.code)
      expect(data['creditAmount']).to eq(10)
      expect(data['user']).to be_nil
    end
  end

  describe 'user-specific promo codes' do
    context 'when user has a valid user-specific promo code' do
      let!(:user_specific_promo) do
        create(:promo_code,
          credit_amount: 25,
          usage_limit: 1,
          times_redeemed: 0,
          expires_at: 1.week.from_now,
          user_id: user.id
        )
      end

      it 'returns the user-specific promo code' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(user_specific_promo.code)
        expect(data['creditAmount']).to eq(25)
        expect(data['user']['id']).to eq(user.id.to_s)
      end
    end

    context 'when user has both user-specific and general promo codes' do
      let!(:general_promo) do
        create(:promo_code,
          credit_amount: 10,
          user_id: nil,
          created_at: 1.hour.ago
        )
      end

      let!(:user_specific_promo) do
        create(:promo_code,
          credit_amount: 25,
          user_id: user.id,
          usage_limit: 1,
          created_at: 30.minutes.ago
        )
      end

      it 'prioritizes user-specific promo code over general ones' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(user_specific_promo.code)
        expect(data['creditAmount']).to eq(25)
        expect(data['user']['id']).to eq(user.id.to_s)
      end
    end

    context 'when user-specific promo code is expired' do
      let!(:expired_user_promo) do
        create(:promo_code,
          credit_amount: 25,
          user_id: user.id,
          usage_limit: 1,
          expires_at: 1.day.ago
        )
      end

      let!(:general_promo) do
        create(:promo_code,
          credit_amount: 10,
          user_id: nil
        )
      end

      it 'falls back to general promo code' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(general_promo.code)
        expect(data['creditAmount']).to eq(10)
        expect(data['userId']).to be_nil
      end
    end

    context 'when user-specific promo code has already been redeemed' do
      let!(:redeemed_user_promo) do
        create(:promo_code,
          credit_amount: 25,
          user_id: user.id,
          usage_limit: 1,
          times_redeemed: 0
        )
      end

      let!(:general_promo) do
        create(:promo_code,
          credit_amount: 10,
          user_id: nil
        )
      end

      before do
        create(:promo_code_redemption, user: user, promo_code: redeemed_user_promo)
      end

      it 'falls back to general promo code' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(general_promo.code)
        expect(data['creditAmount']).to eq(10)
        expect(data['userId']).to be_nil
      end
    end

    context 'when user-specific promo code has reached usage limit' do
      let!(:limit_reached_user_promo) do
        create(:promo_code,
          credit_amount: 25,
          user_id: user.id,
          usage_limit: 1,
          times_redeemed: 1
        )
      end

      let!(:general_promo) do
        create(:promo_code,
          credit_amount: 10,
          user_id: nil
        )
      end

      it 'falls back to general promo code' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(general_promo.code)
        expect(data['creditAmount']).to eq(10)
        expect(data['userId']).to be_nil
      end
    end

    context 'when user has no valid promo codes but other users do' do
      let!(:other_user_promo) do
        create(:promo_code,
          credit_amount: 30,
          user_id: other_user.id,
          usage_limit: 1,
        )
      end

      it 'returns nil (does not return other users promo codes)' do
        exec_query
        json_response = JSON.parse(response.body)
        expect(json_response.dig('data', 'userPromoCode')).to be_nil
      end
    end
  end

  describe 'promo code ordering' do
    context 'when multiple valid user-specific promo codes exist' do
      let!(:older_user_promo) do
        create(:promo_code,
          credit_amount: 15,
          user_id: user.id,
          usage_limit: 1,
          created_at: 2.hours.ago
        )
      end

      let!(:newer_user_promo) do
        create(:promo_code,
          credit_amount: 20,
          user_id: user.id,
          usage_limit: 1,
          created_at: 1.hour.ago,
        )
      end

      it 'returns the newest user-specific promo code' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(newer_user_promo.code)
        expect(data['creditAmount']).to eq(20)
      end
    end

    context 'when multiple valid general promo codes exist' do
      let!(:older_general_promo) do
        create(:promo_code,
          credit_amount: 5,
          user_id: nil,
          created_at: 2.hours.ago
        )
      end

      let!(:newer_general_promo) do
        create(:promo_code,
          credit_amount: 15,
          user_id: nil,
          created_at: 1.hour.ago
        )
      end

      it 'returns the newest general promo code' do
        exec_query
        json_response = JSON.parse(response.body)
        data = json_response.dig('data', 'userPromoCode')
        expect(data['code']).to eq(newer_general_promo.code)
        expect(data['creditAmount']).to eq(15)
      end
    end
  end
end
