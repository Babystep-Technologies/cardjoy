# typed: true

module Types
  # One line of an organization's shared credit ledger (#128), for the credits
  # page to render as history: when, why, how much, and who.
  #
  # Only ever reached through OrganizationType#credits, which is admin-gated —
  # the pool's history names the members who received credits and the admin who
  # paid for them, which is more than a plain member needs to see their balance.
  class OrganizationCreditType < Types::BaseObject
    field :id, ID, null: false
    # Signed: positive put credits into the pool, negative took them out.
    field :amount, Integer, null: false
    field :reason, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # Both nullable: a chargeback reversal names nobody, and a row can outlive
    # the account it names.
    field :actor, Types::UserType, null: true,
      description: "Who caused this row — the buyer of a purchase, the admin behind an allocation."
    field :member, Types::UserType, null: true,
      description: "The member an allocation went to. Null on every other kind of row."

    # `amount` is nullable in the table, as it is on the personal ledger; a row
    # without one moves no credits.
    def amount
      object.amount.to_i
    end

    def actor
      load_user(object.actor_user_id)
    end

    def member
      load_user(object.member_user_id)
    end

    private

    def load_user(id)
      return nil unless id

      dataloader.with(Sources::UserById).load(id)
    end
  end
end
