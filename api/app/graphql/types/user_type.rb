# typed: true

module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :email, String, null: false
    field :name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :credit_balance, Integer, null: false
    # The postage wallet (#145) — a separate, cents-denominated balance from
    # `credit_balance`, which stays in whole credits. Integer cents on the wire;
    # the client formats it.
    field :postage_balance_cents, Integer, null: false,
      description: "Balance of the postage wallet, in US cents. Zero for a user who has never topped up."
    field :cards_count, Integer, null: false
    field :invitations_count, Integer, null: false
    # Null means Personal — a valid context, not a missing organization.
    field :active_organization, Types::OrganizationType, null: true
    field :organization_memberships, [ Types::OrganizationMembershipType ], null: false

    # Archived organizations keep their membership rows (deleteOrganization is a
    # soft delete), so filter them out here rather than handing the org switcher
    # entries whose `organization` is null.
    def organization_memberships
      object.organization_memberships.where(organization_id: Organization.select(:id))
    end

    def credit_balance
      object.credit_balance
    end

    def postage_balance_cents
      object.postage_balance_cents
    end

    def cards_count
      object.cards.count
    end

    def invitations_count
      object.invitations.count
    end
  end
end
