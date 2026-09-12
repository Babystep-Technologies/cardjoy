# typed: true

module Mutations
  # Ends a promo code immediately (#180), by moving its expiry into the past
  # rather than deleting it — its redemption history stays intact and
  # queryable.
  class ExpirePromoCode < BaseMutation
    NOT_FOUND_ERROR = "Promo code not found"

    argument :id, ID, required: true

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      promo_code = PromoCode.find_by(id: id)
      return failure([ NOT_FOUND_ERROR ]) unless promo_code

      promo_code.expire!

      { promo_code: promo_code, errors: [] }
    end

    private

    def failure(errors)
      { promo_code: nil, errors: errors }
    end
  end
end
