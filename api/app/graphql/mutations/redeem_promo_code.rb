# typed: true

# app/graphql/mutations/redeem_promo_code.rb
module Mutations
  class RedeemPromoCode < BaseMutation
    argument :code, String, required: true

    field :success, Boolean, null: false
    field :credit_amount, Integer, null: true
    field :error, String, null: true

    def resolve(code:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, "Authentication required" unless user

      promo = PromoCode.find_by(code: code.downcase.strip)
      if promo.nil?
        raise GraphQL::ExecutionError, "Invalid promo code"
      end

      # Check if this is a user-specific promo code that can only be used by the assigned user
      if promo.user_id.present? && promo.user_id != user.id
        raise GraphQL::ExecutionError, "This promo code is not available for your account"
      end

      if promo.expires_at&.< Time.current
        raise GraphQL::ExecutionError, "Promo code has expired"
      end

      if promo.times_redeemed.to_i >= T.must(promo.usage_limit)
        raise GraphQL::ExecutionError, "Promo code has reached its limit"
      end

      if PromoCodeRedemption.exists?(user: user, promo_code: promo)
        raise GraphQL::ExecutionError, "You've already redeemed this promo code"
      end

      # Log redemption
      PromoCodeRedemption.create!(user: user, promo_code: promo)
      promo.increment!(:times_redeemed)

      # Issue credits
      Credit.create!(
        user: user,
        amount: promo.credit_amount,
        reason: "promotion",
        events: [
          {
            event_kind: "promo_code_redeemed",
            event_happened_at: Time.now.utc.iso8601(3),
            event_data: { promo_code: promo.code }
          }
        ]
      )

      {
        success: true,
        credit_amount: promo.credit_amount
      }

    rescue => e
      {
        success: false,
        error: e.message
      }
    end
  end
end
