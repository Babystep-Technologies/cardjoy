# typed: true

module Mutations
  # Put credits into an organization's shared pool as a goodwill gesture, to
  # make good on a failed payment, or to honour a sales agreement (#130).
  #
  # Gated on the internal-admin JWT, not on organization membership: staff are
  # not members of the customer organizations they support. That gate raises
  # rather than returning an errors array, matching the other internal-admin
  # writes (see Mutations::UpdateCardByAdmin).
  #
  # A grant is a plain positive row on the append-only ledger; there is no
  # matching "revoke", because correcting one means appending a negative row,
  # not editing history.
  class GrantOrganizationCredits < BaseMutation
    NOT_FOUND_ERROR = "Organization not found"
    INVALID_AMOUNT_ERROR = "Amount must be positive"

    REASON = "admin_grant"
    EVENT_KIND = "admin_grant"

    argument :organization_id, ID, required: true
    argument :amount, Integer, required: true

    field :organization, Types::AdminOrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, amount:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Archived organizations are out of Organization's default scope, so this
      # reads as not-found for them too — the same answer the list and detail
      # queries give.
      organization = Organization.find_by(id: organization_id)
      return failure([ NOT_FOUND_ERROR ]) unless organization

      # A negative "grant" would silently drain a customer's pool; taking
      # credits back is not this mutation's job.
      return failure([ INVALID_AMOUNT_ERROR ]) unless amount.positive?

      organization.organization_credits.create!(
        amount: amount,
        reason: REASON,
        events: [ grant_event(organization: organization, admin: admin, amount: amount) ]
      )

      { organization: organization.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    # `granted_by_admin_id` names an Admin, not a User, which is why the grant
    # shows no `actor` on the customer-facing ledger — OrganizationCreditType
    # resolves actors out of `purchased_by_user_id`/`allocated_by_user_id`, and
    # which staff member handled a ticket is not the customer's business. The
    # id is still recorded here so the audit trail is complete.
    def grant_event(organization:, admin:, amount:)
      {
        event_kind: EVENT_KIND,
        event_happened_at: Time.now.utc.iso8601(3),
        event_data: {
          organization_id: organization.id,
          granted_by_admin_id: admin.id,
          amount: amount
        }
      }
    end

    def failure(errors)
      { organization: nil, errors: errors }
    end
  end
end
