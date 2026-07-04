# typed: true

module Queries
  class GetUserPromoCode < BaseQuery
    type Types::PromoCodeType, null: true

    argument :user_id, ID, required: true

    def resolve(user_id:)
      user = ::User.find_by(id: user_id)
      return nil unless user

      # First, look for user-specific promo codes
      user_specific_promo = PromoCode
        .where(user_id: user.id)
        .where("expires_at IS NULL OR expires_at > ?", Time.current)
        .where("usage_limit IS NULL OR COALESCE(times_redeemed, 0) < usage_limit")
        .order("created_at DESC")
        .find do |promo|
          !PromoCodeRedemption.exists?(user_id: user.id, promo_code_id: promo.id)
        end

      return user_specific_promo if user_specific_promo

      # If no user-specific promo code found, look for general promo codes
      PromoCode
        .where(user_id: nil)
        .where("expires_at IS NULL OR expires_at > ?", Time.current)
        .where("usage_limit IS NULL OR COALESCE(times_redeemed, 0) < usage_limit")
        .order("created_at DESC") # prioritize newer promos
        .find do |promo|
          !PromoCodeRedemption.exists?(user_id: user.id, promo_code_id: promo.id)
        end
    end
  end
end
