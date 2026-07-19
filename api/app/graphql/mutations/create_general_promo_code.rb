# typed: true

# app/graphql/mutations/create_general_promo_code.rb
module Mutations
  class CreateGeneralPromoCode < Mutations::BaseMutation
    # General codes grant a single credit each; the amount is not admin-configurable.
    GENERAL_CREDIT_AMOUNT = 1

    argument :usage_limit, Integer, required: true
    argument :code, String, required: false
    argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(usage_limit:, code: nil, expires_at: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin

      promo = PromoCode.create!(
        credit_amount: GENERAL_CREDIT_AMOUNT,
        usage_limit: usage_limit,
        times_redeemed: 0,
        code: code.presence || PromoCode.generate_unique_code,
        expires_at: expires_at
      )

      { promo_code: promo, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      { promo_code: nil, errors: e.record.errors.full_messages }
    end
  end
end
