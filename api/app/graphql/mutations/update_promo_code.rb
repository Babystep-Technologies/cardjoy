# typed: true

module Mutations
  # Edits a promo code's amount, usage limit, and/or expiry (#180) — the terms
  # a code was created with can otherwise never change once a typo or a
  # campaign adjustment is discovered. Refuses once the code has been redeemed
  # at all: changing the terms after real credits have gone out under the old
  # ones would make those redemptions inconsistent with what the code now
  # says.
  class UpdatePromoCode < BaseMutation
    NOT_FOUND_ERROR = "Promo code not found"
    ALREADY_REDEEMED_ERROR = "Promo code has already been redeemed and cannot be edited"

    argument :id, ID, required: true
    argument :credit_amount, Integer, required: false
    argument :usage_limit, Integer, required: false
    argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, credit_amount: nil, usage_limit: nil, expires_at: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      promo_code = PromoCode.find_by(id: id)
      return failure([ NOT_FOUND_ERROR ]) unless promo_code

      promo_code.update_by_admin!(credit_amount: credit_amount, usage_limit: usage_limit, expires_at: expires_at)

      { promo_code: promo_code.reload, errors: [] }
    rescue PromoCode::AlreadyPartiallyRedeemedError
      failure([ ALREADY_REDEEMED_ERROR ])
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def failure(errors)
      { promo_code: nil, errors: errors }
    end
  end
end
