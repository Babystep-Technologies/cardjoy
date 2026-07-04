# typed: true

class PromoCode < ApplicationRecord
  belongs_to :user, optional: true
  has_many :promo_code_redemptions, dependent: :destroy

  # Validation: user-specific promo codes can only be used once
  validates :usage_limit, inclusion: { in: [ 1 ] }, if: :user_specific?

  private

  def user_specific?
    user_id.present?
  end
end
