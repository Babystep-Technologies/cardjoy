# typed: true

module Types
  # One line of a user's personal credit ledger, for the admin user detail page
  # (#180) — when, why, and how much. Mirrors Types::PostageCreditType and
  # Types::OrganizationCreditType, the other two ledgers' row shapes.
  #
  # Only ever reached through Types::AdminUserType#credits, which is
  # admin-gated; there is no path to another user's ledger from a non-admin
  # query today.
  class CreditType < Types::BaseObject
    field :id, ID, null: false
    # Signed: positive rows are grants/purchases, negative rows are spends.
    field :amount, Integer, null: false
    field :reason, String, null: true
    # The free-text reason behind an admin_adjustment row; null on every other
    # kind, whose `reason` column already says enough.
    field :note, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def amount
      object.amount.to_i
    end
  end
end
