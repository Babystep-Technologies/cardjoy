# typed: true

module Mutations
  # Staff kill switch for a promo code (#180), distinct from letting it
  # expire: a leaked or misused code needs to stop working right now, not on
  # whatever schedule it was originally given.
  class DisablePromoCode < BaseMutation
    NOT_FOUND_ERROR = "Promo code not found"

    argument :id, ID, required: true

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      promo_code = PromoCode.find_by(id: id)
      return failure([ NOT_FOUND_ERROR ]) unless promo_code

      promo_code.disable!

      { promo_code: promo_code, errors: [] }
    end

    private

    def failure(errors)
      { promo_code: nil, errors: errors }
    end
  end
end
