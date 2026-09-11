require 'rails_helper'

RSpec.describe PromoCode, type: :model do
  describe 'validations' do
    it 'requires a code' do
      promo = build(:promo_code, code: nil)
      expect(promo).not_to be_valid
      expect(promo.errors[:code]).to include("can't be blank")
    end

    it 'requires a unique code (case-insensitive)' do
      create(:promo_code, code: 'welcome')
      promo = build(:promo_code, code: 'WELCOME')
      expect(promo).not_to be_valid
      expect(promo.errors[:code]).to include('has already been taken')
    end

    it 'requires a positive credit_amount' do
      expect(build(:promo_code, credit_amount: 0)).not_to be_valid
    end

    it 'requires a positive usage_limit' do
      expect(build(:promo_code, usage_limit: 0)).not_to be_valid
    end

    it 'forces usage_limit to 1 for user-specific codes' do
      promo = build(:promo_code, user: create(:user), usage_limit: 5)
      expect(promo).not_to be_valid
      expect(promo.errors[:usage_limit]).to be_present
    end
  end

  describe 'normalization' do
    it 'downcases and strips the code before validation' do
      promo = create(:promo_code, code: '  MixedCase  ')
      expect(promo.code).to eq 'mixedcase'
    end
  end

  describe '.generate_unique_code' do
    it 'returns a cj-prefixed code that is not already taken' do
      code = described_class.generate_unique_code
      expect(code).to match(/\Acj-[a-z0-9]{8}\z/)
      expect(described_class.exists?(code: code)).to be false
    end
  end

  describe '#redeem!' do
    let(:user) { create(:user) }
    let(:promo) { create(:promo_code, credit_amount: 10, usage_limit: 1, times_redeemed: 0) }

    it 'records the redemption, bumps times_redeemed, and grants credit' do
      credit_amount = promo.redeem!(user: user)

      expect(credit_amount).to eq 10
      expect(PromoCodeRedemption.exists?(user: user, promo_code: promo)).to be true
      expect(promo.reload.times_redeemed).to eq 1
      expect(user.credits.last.amount).to eq 10
    end

    it 'raises ExpiredError without redeeming when expires_at has passed' do
      promo.update!(expires_at: 1.day.ago)
      credits_before = user.credits.count

      expect { promo.redeem!(user: user) }.to raise_error(PromoCode::ExpiredError)
      expect(promo.reload.times_redeemed).to eq 0
      expect(user.reload.credits.count).to eq credits_before
    end

    it 'raises UsageLimitReachedError without redeeming when the limit is hit' do
      promo.update!(usage_limit: 1, times_redeemed: 1)
      credits_before = user.credits.count

      expect { promo.redeem!(user: user) }.to raise_error(PromoCode::UsageLimitReachedError)
      expect(user.reload.credits.count).to eq credits_before
    end

    it 'raises AlreadyRedeemedError without granting a second credit' do
      create(:promo_code_redemption, user: user, promo_code: promo)
      promo.update!(usage_limit: 100)
      credits_before = user.credits.count

      expect { promo.redeem!(user: user) }.to raise_error(PromoCode::AlreadyRedeemedError)
      expect(user.reload.credits.count).to eq credits_before
    end

    it 'rolls back the redemption and counter if issuing credit fails' do
      allow(Credit).to receive(:create!).and_raise(StandardError, 'boom')

      expect { promo.redeem!(user: user) }.to raise_error('boom')
      expect(PromoCodeRedemption.exists?(user: user, promo_code: promo)).to be false
      expect(promo.reload.times_redeemed).to eq 0
    end

    # Uses real threads on separate DB connections, so the data must be
    # committed (truncation, not a wrapping transaction) to be visible across
    # them.
    describe 'concurrency', :truncation do
      self.use_transactional_tests = false

      it 'grants credit exactly once for a usage_limit: 1 code redeemed concurrently' do
        promo = create(:promo_code, credit_amount: 10, usage_limit: 1, times_redeemed: 0)
        user = create(:user)

        # Two threads race to redeem the same single-use code as the same
        # user. The row lock + unique index in #redeem! must let exactly one
        # win (#186).
        succeeded = Concurrent::AtomicFixnum.new(0)
        failed = Concurrent::AtomicFixnum.new(0)

        threads = 2.times.map do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              PromoCode.find(promo.id).redeem!(user: User.find(user.id))
              succeeded.increment
            rescue PromoCode::UsageLimitReachedError, PromoCode::AlreadyRedeemedError
              failed.increment
            end
          end
        end
        threads.each(&:join)

        expect(succeeded.value).to eq(1)
        expect(failed.value).to eq(1)
        expect(promo.reload.times_redeemed).to eq(1)
        expect(PromoCodeRedemption.where(user: user, promo_code: promo).count).to eq(1)
        expect(user.reload.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT + 10)
      end
    end
  end
end
