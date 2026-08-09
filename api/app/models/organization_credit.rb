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

  private

  def allowed_event_kinds
    EVENT_KINDS
  end
end
