# typed: true

# An organization's shared credit pool — the same append-only ledger as Credit,
# keyed on an organization rather than a user. Positive rows put credits into
# the pool (a purchase or an admin grant), negative rows take them out (an
# allocation to a member, or a reversal after a lost dispute).
#
# Note that `organization` reads nil once the organization is archived, because
# Organization is default-scoped to `deleted_at: nil`.
class OrganizationCredit < ApplicationRecord
  include CreditLedger

  belongs_to :organization

  scope :available, -> { where("amount > 0") }

  EVENT_KINDS = %w[
    org_credit_purchased
    org_credit_allocated
    admin_grant
    org_credit_reversed_due_to_chargeback
  ].freeze

  # The two people a ledger row can name, read back out of the audit trail so
  # the credits page can render "who" next to each line (#128). The `events`
  # jsonb is the only record of them — the table itself carries no user column.
  #
  # Ids arrive as integers from our own writes and as strings from Stripe
  # metadata (`purchased_by_user_id`), so both are normalized here rather than
  # at every call site.

  # Whoever caused the row: the buyer of a purchase, the admin behind an
  # allocation. Nil for a chargeback reversal, which no person initiated.
  def actor_user_id
    user_id_from_event("purchased_by_user_id") || user_id_from_event("allocated_by_user_id")
  end

  # The member an allocation went to; nil on every other kind of row.
  def member_user_id
    user_id_from_event("user_id")
  end

  private

  def user_id_from_event(key)
    events&.first&.dig("event_data", key)&.to_i
  end

  def allowed_event_kinds
    EVENT_KINDS
  end
end
