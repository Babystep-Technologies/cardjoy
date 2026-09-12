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

      credit_amount = promo.redeem!(user: user)

      {
        success: true,
        credit_amount: credit_amount
      }
    rescue PromoCode::ExpiredError
      { success: false, error: "Promo code has expired" }
    rescue PromoCode::DisabledError
      { success: false, error: "Promo code is no longer available" }
    rescue PromoCode::UsageLimitReachedError
      { success: false, error: "Promo code has reached its limit" }
    rescue PromoCode::AlreadyRedeemedError
      { success: false, error: "You've already redeemed this promo code" }
    rescue GraphQL::ExecutionError => e
      { success: false, error: e.message }
    rescue StandardError => e
      # Distinct from the GraphQL::ExecutionError branch above: everything
      # here is an unanticipated failure, not a deliberate validation
      # rejection, so it's worth logging (#186).
      Rails.logger.error("RedeemPromoCode: #{e.class}: #{e.message}")
      { success: false, error: e.message }
    end
  end
end
