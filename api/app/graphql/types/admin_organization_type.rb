# typed: true

module Types
  # An organization as internal staff see it (#130).
  #
  # Deliberately separate from Types::OrganizationType rather than a set of
  # extra fields on it. That type gates its roster and ledger on
  # `object.membership_for(context[:current_user])`, and an admin JWT carries an
  # `admin_id` with no `current_user` at all — so every gated field would come
  # back empty here. The gate on this type is the internal-admin one, applied
  # once by the resolvers that hand it out (Queries::AdminOrganizations,
  # Queries::AdminOrganization, Mutations::GrantOrganizationCredits); nothing
  # else in the schema returns this type.
  class AdminOrganizationType < Types::BaseObject
    # Support reads a pool's history to answer "where did the balance go", and
    # a year-old organization has a long one, so it is capped rather than
    # returned whole. Same shape as OrganizationType's own limit.
    CREDITS_DEFAULT_LIMIT = 50
    CREDITS_MAX_LIMIT = 200

    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :description, String, null: true
    field :members_count, Integer, null: false
    field :credit_balance, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # The roster, oldest first, so it doesn't reshuffle between loads and the
    # founding admins stay at the top. Each entry's `user` carries that
    # member's own `creditBalance`, which is what support is usually asked
    # about ("I have no credits" from someone in an org with a full pool).
    field :memberships, [ Types::OrganizationMembershipType ], null: false

    # The pool ledger, newest first: the top is the purchase, allocation, or
    # grant support is currently looking into.
    field :credits, [ Types::OrganizationCreditType ], null: false do
      argument :limit, Integer, required: false,
        description: "How many of the most recent rows to return (default #{CREDITS_DEFAULT_LIMIT}, max #{CREDITS_MAX_LIMIT})."
    end

    def members_count
      object.organization_memberships.count
    end

    def memberships
      object.organization_memberships.includes(:user).order(:created_at, :id)
    end

    # `limit` arrives nil when the client passes an explicit null, which is not
    # the same as omitting the argument — both mean "the default".
    def credits(limit: nil)
      object.organization_credits
        .order(created_at: :desc, id: :desc)
        .limit((limit || CREDITS_DEFAULT_LIMIT).clamp(1, CREDITS_MAX_LIMIT))
    end
  end
end
