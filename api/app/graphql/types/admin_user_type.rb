# typed: true

module Types
  # A user as internal staff see it (#180) — the profile a support agent lands
  # on from a ticket or the users list: who they are, their credit history, and
  # what they've made.
  #
  # Deliberately separate from Types::UserType rather than a set of gated
  # fields on it, for the same reason as Types::AdminOrganizationType: an admin
  # JWT carries no `current_user`, so anything gated on the caller would come
  # back empty here. Only Queries::AdminUser and Mutations::AdjustUserCredits
  # return this type.
  class AdminUserType < Types::BaseObject
    # Same shape as AdminOrganizationType's ledger cap.
    CREDITS_DEFAULT_LIMIT = 25
    CREDITS_MAX_LIMIT = 200

    # How many of the most recent cards/invitations/holiday cards the detail
    # page shows inline. The full history for each is one click away, at
    # /cards?q=<email> and friends — this is a preview, not another list.
    RECENT_PRODUCT_LIMIT = 10

    field :id, ID, null: false
    field :email, String, null: false
    field :name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :email_confirmed, Boolean, null: false
    field :credit_balance, Integer, null: false
    # Null means Personal — a valid context, not a missing organization.
    field :active_organization, Types::OrganizationType, null: true

    # The personal ledger, newest first, paginated the same way
    # AdminOrganizationType#credits is.
    field :credits, [ Types::CreditType ], null: false do
      argument :limit, Integer, required: false,
        description: "Rows per page (default #{CREDITS_DEFAULT_LIMIT}, max #{CREDITS_MAX_LIMIT})."
      argument :page, Integer, required: false, description: "1-based. Defaults to 1."
    end
    field :credits_count, Integer, null: false

    field :cards, [ Types::CardType ], null: false,
      description: "The #{RECENT_PRODUCT_LIMIT} most recently created."
    field :cards_count, Integer, null: false
    field :invitations, [ Types::InvitationType ], null: false,
      description: "The #{RECENT_PRODUCT_LIMIT} most recently created."
    field :invitations_count, Integer, null: false
    field :holiday_cards, [ Types::HolidayCardType ], null: false,
      description: "The #{RECENT_PRODUCT_LIMIT} most recently created."
    field :holiday_cards_count, Integer, null: false

    def credit_balance
      object.credit_balance
    end

    def credits(limit: nil, page: nil)
      limit = (limit || CREDITS_DEFAULT_LIMIT).clamp(1, CREDITS_MAX_LIMIT)
      page = [ (page || 1).to_i, 1 ].max

      object.credits
        .order(created_at: :desc, id: :desc)
        .offset((page - 1) * limit)
        .limit(limit)
    end

    def credits_count
      object.credits.count
    end

    def cards
      object.cards.order(created_at: :desc).limit(RECENT_PRODUCT_LIMIT)
    end

    def cards_count
      object.cards.count
    end

    def invitations
      object.invitations.order(created_at: :desc).limit(RECENT_PRODUCT_LIMIT)
    end

    def invitations_count
      object.invitations.count
    end

    def holiday_cards
      object.holiday_cards.order(created_at: :desc).limit(RECENT_PRODUCT_LIMIT)
    end

    def holiday_cards_count
      object.holiday_cards.count
    end
  end
end
