# typed: true

# app/graphql/mutations/create_general_promo_code.rb
module Mutations
  class CreateGeneralPromoCode < Mutations::BaseMutation
    # The default when `creditAmount` is omitted, so an existing caller that
    # doesn't yet pass it keeps getting the behavior it always has (#180).
    GENERAL_CREDIT_AMOUNT = 1

    argument :usage_limit, Integer, required: true
    argument :credit_amount, Integer, required: false, default_value: GENERAL_CREDIT_AMOUNT
    argument :code, String, required: false
    argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(usage_limit:, credit_amount:, code: nil, expires_at: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      promo = PromoCode.create!(
        credit_amount: credit_amount,
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
