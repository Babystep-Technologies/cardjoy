# typed: true

module Mutations
  # Staff correction to one user's personal credit balance (#180): a goodwill
  # grant (positive `amount`) or a correction for a mistake such as a double
  # charge (negative), each requiring a free-text `reason` the admin must
  # supply to justify it. Before this the only staff path to a customer's
  # balance was mailing them a single-use promo code and hoping they redeem
  # it.
  #
  # Gated on the internal-admin JWT, like the rest of the internal-admin
  # writes (see Mutations::UpdateCardByAdmin). Raises rather than returning an
  # errors array for that gate, matching the other internal-admin mutations.
  class AdjustUserCredits < BaseMutation
    NOT_FOUND_ERROR = "User not found"
    REASON_REQUIRED_ERROR = "Reason is required"
    WOULD_OVERDRAFT_ERROR = "Amount would drive balance below zero"

    argument :user_id, ID, required: true
    argument :amount, Integer, required: true
    argument :reason, String, required: true

    field :user, Types::UserType, null: true
    field :errors, [ String ], null: false

    def resolve(user_id:, amount:, reason:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      user = User.find_by(id: user_id)
      return failure([ NOT_FOUND_ERROR ]) unless user
      return failure([ REASON_REQUIRED_ERROR ]) if reason.blank?

      ApplicationRecord.transaction do
        user.adjust_credits!(amount: amount, reason: reason, admin: admin)
      end

      { user: user.reload, errors: [] }
    rescue User::CreditAdjustmentWouldOverdraftError
      failure([ WOULD_OVERDRAFT_ERROR ])
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def failure(errors)
      { user: nil, errors: errors }
    end
  end
end
