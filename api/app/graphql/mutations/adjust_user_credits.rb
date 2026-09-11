# typed: true

module Mutations
  # A grant or correction to a user's personal credit balance, with a reason
  # support has to type before it can save (#180) — the write behind the
  # "Grant or adjust credits" action on the user detail page. `amount` may be
  # negative, so this covers both directions rather than needing a separate
  # deduction mutation.
  #
  # Mirrors Mutations::AdjustOrganizationCredits: the reason lands on
  # Credit#note rather than the categorical `reason` column, since the reason
  # here is whatever the situation actually was.
  #
  # Gated on the internal-admin JWT, not on the caller being the user in
  # question — this is a support tool, not a self-service one.
  class AdjustUserCredits < Mutations::BaseMutation
    NOT_FOUND_ERROR = "User not found"
    BLANK_REASON_ERROR = "Reason is required"
    ZERO_AMOUNT_ERROR = "Amount must not be zero"
    INSUFFICIENT_BALANCE_ERROR = "Not enough credits"

    REASON = "admin_adjustment"
    EVENT_KIND = "admin_adjustment"

    argument :user_id, ID, required: true
    argument :amount, Integer, required: true
    argument :reason, String, required: true

    field :user, Types::AdminUserType, null: true
    field :errors, [ String ], null: false

    def resolve(user_id:, amount:, reason:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      user = User.find_by(id: user_id)
      return failure([ NOT_FOUND_ERROR ]) unless user
      return failure([ ZERO_AMOUNT_ERROR ]) if amount.zero?
      return failure([ BLANK_REASON_ERROR ]) if reason.blank?

      ActiveRecord::Base.transaction do
        # Locks the user row for the duration of the transaction, the same
        # guard User#spend_credit! uses, so a concurrent spend or adjustment
        # can't also pass the balance check and drive the balance negative.
        user.lock!
        if user.credit_balance + amount < 0
          raise User::InsufficientCreditsError
        end

        user.credits.create!(
          amount: amount,
          reason: REASON,
          events: [ adjustment_event(user: user, admin: admin, amount: amount, reason: reason) ]
        )
      end

      { user: user.reload, errors: [] }
    rescue User::InsufficientCreditsError
      failure([ INSUFFICIENT_BALANCE_ERROR ])
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def adjustment_event(user:, admin:, amount:, reason:)
      {
        event_kind: EVENT_KIND,
        event_happened_at: Time.now.utc.iso8601(3),
        event_data: {
          user_id: user.id,
          adjusted_by_admin_id: admin.id,
          amount: amount,
          note: reason
        }
      }
    end

    def failure(errors)
      { user: nil, errors: errors }
    end
  end
end
