# typed: true

module Mutations
  # A correction to an organization's shared pool, with a reason support has to
  # type before it can save (#180). Where Mutations::GrantOrganizationCredits is
  # always a positive goodwill grant with a fixed reason, this is the general
  # tool: `amount` may be negative — reversing an over-grant, clawing back a
  # mistaken allocation — and every row it writes carries the reason as
  # OrganizationCredit#note rather than a categorical `reason` string, because
  # the reason here is whatever the situation actually was.
  #
  # Gated on the internal-admin JWT, not on organization membership, matching
  # every other internal-admin write.
  class AdjustOrganizationCredits < Mutations::BaseMutation
    NOT_FOUND_ERROR = "Organization not found"
    BLANK_REASON_ERROR = "Reason is required"
    ZERO_AMOUNT_ERROR = "Amount must not be zero"
    INSUFFICIENT_BALANCE_ERROR = "Not enough credits in the pool"

    REASON = "admin_adjustment"
    EVENT_KIND = "admin_adjustment"

    argument :organization_id, ID, required: true
    argument :amount, Integer, required: true
    argument :reason, String, required: true

    field :organization, Types::AdminOrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, amount:, reason:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Archived organizations are out of Organization's default scope, so this
      # reads as not-found for them too — the same answer the list and detail
      # queries give.
      organization = Organization.find_by(id: organization_id)
      return failure([ NOT_FOUND_ERROR ]) unless organization
      return failure([ ZERO_AMOUNT_ERROR ]) if amount.zero?
      return failure([ BLANK_REASON_ERROR ]) if reason.blank?

      ActiveRecord::Base.transaction do
        # Locks the organization row for the duration of the transaction, the
        # same guard Organization#allocate_credits! uses, so two corrections in
        # flight at once can't both pass the balance check and overdraw the pool.
        organization.lock!
        if organization.credit_balance + amount < 0
          raise Organization::InsufficientPoolCreditsError
        end

        organization.organization_credits.create!(
          amount: amount,
          reason: REASON,
          events: [ adjustment_event(organization: organization, admin: admin, amount: amount, reason: reason) ]
        )
      end

      { organization: organization.reload, errors: [] }
    rescue Organization::InsufficientPoolCreditsError
      failure([ INSUFFICIENT_BALANCE_ERROR ])
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def adjustment_event(organization:, admin:, amount:, reason:)
      {
        event_kind: EVENT_KIND,
        event_happened_at: Time.now.utc.iso8601(3),
        event_data: {
          organization_id: organization.id,
          adjusted_by_admin_id: admin.id,
          amount: amount,
          note: reason
        }
      }
    end

    def failure(errors)
      { organization: nil, errors: errors }
    end
  end
end
