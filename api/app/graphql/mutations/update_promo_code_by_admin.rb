# typed: true

module Mutations
  # The lifecycle actions on the credits page's row menu (#180): pull a code out
  # of circulation early, or put a disabled one back. Mirrors
  # Mutations::UpdateCardByAdmin action for action; field edits (code, amount,
  # limit, expiry) are Mutations::EditPromoCodeByAdmin instead, since those
  # carry their own validation rather than a fixed action name.
  class UpdatePromoCodeByAdmin < Mutations::BaseMutation
    VALID_ACTIONS = %w[expire disable enable].freeze

    argument :id, ID, required: true
    argument :action, String, required: true

    field :promo_code, Types::PromoCodeType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, action:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      promo_code = PromoCode.find_by(id: id)
      return failure([ "Promo code not found" ]) unless promo_code
      return failure([ "Invalid action" ]) unless VALID_ACTIONS.include?(action)

      case action
      when "expire" then promo_code.expire!
      when "disable" then promo_code.disable!
      when "enable" then promo_code.enable!
      end

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
