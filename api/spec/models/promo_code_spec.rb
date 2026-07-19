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
end
