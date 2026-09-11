# typed: true

module Mutations
  # Field edits from the credits page's row menu (#180): code, credit amount,
  # usage limit, expiry. Only the arguments actually passed are changed — an
  # argument left out (or sent as null) leaves that field as it was, the same
  # "nil means unchanged" contract Mutations::UpdateOrganization uses for its
  # optional fields.
  #
  # Validation is the model's own (PromoCode already refuses a usage_limit other
  # than 1 on a user-specific code, a blank code, etc.), surfaced through
  # `errors` rather than raised, so a bad edit reads like any other form error.
  class EditPromoCodeByAdmin < Mutations::BaseMutation
    argument :id, ID, required: true
    argument :code, String, required: false
    argument :credit_amount, Integer, required: false
    argument :usage_limit, Integer, required: false
    argument :expires_at, GraphQL::Types::ISO8601DateTime, required: false

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, code: nil, credit_amount: nil, usage_limit: nil, expires_at: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      promo_code = PromoCode.find_by(id: id)
      return failure([ "Promo code not found" ]) unless promo_code

      attributes = {
        code: code,
        credit_amount: credit_amount,
        usage_limit: usage_limit,
        expires_at: expires_at
      }.compact

      promo_code.update!(attributes)
      { promo_code: promo_code.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def failure(errors)
      { promo_code: nil, errors: errors }
    end
  end
end
