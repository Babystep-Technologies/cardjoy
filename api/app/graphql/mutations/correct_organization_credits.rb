# typed: true

module Mutations
  # Append a negative row to an organization's shared pool to correct a
  # mis-keyed grant (#180) — the case Mutations::GrantOrganizationCredits
  # cannot cover, because it deliberately keeps rejecting a non-positive
  # amount so an accidental negative in the grant form still errors. This is
  # the one mutation whose entire job is writing that negative row on purpose.
  #
  # Gated on the internal-admin JWT, like GrantOrganizationCredits. Locks the
  # organization row for the duration of the write, the same guard
  # Organization#allocate_credits! relies on.
  class CorrectOrganizationCredits < BaseMutation
    NOT_FOUND_ERROR = "Organization not found"
    INVALID_AMOUNT_ERROR = "Amount must be negative"
    REASON_REQUIRED_ERROR = "Reason is required"

    EVENT_KIND = "admin_correction"

    argument :organization_id, ID, required: true
    argument :amount, Integer, required: true
    argument :reason, String, required: true

    field :organization, Types::AdminOrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, amount:, reason:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Archived organizations are out of Organization's default scope, so
      # this reads as not-found for them too — the same answer the list and
      # detail queries give.
      organization = Organization.find_by(id: organization_id)
      return failure([ NOT_FOUND_ERROR ]) unless organization
      return failure([ INVALID_AMOUNT_ERROR ]) unless amount.negative?
      return failure([ REASON_REQUIRED_ERROR ]) if reason.blank?

      ApplicationRecord.transaction do
        organization.lock!
        organization.organization_credits.create!(
          amount: amount,
          reason: reason,
          events: [ correction_event(organization: organization, admin: admin, amount: amount, reason: reason) ]
        )
      end

      { organization: organization.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def correction_event(organization:, admin:, amount:, reason:)
      {
        event_kind: EVENT_KIND,
        event_happened_at: Time.now.utc.iso8601(3),
        event_data: {
          organization_id: organization.id,
          corrected_by_admin_id: admin.id,
          amount: amount,
          reason: reason
        }
      }
    end

    def failure(errors)
      { organization: nil, errors: errors }
    end
  end
end
