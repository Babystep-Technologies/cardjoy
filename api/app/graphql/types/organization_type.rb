# typed: true

module Types
  class OrganizationType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :description, String, null: true
    field :members_count, Integer, null: false
    field :credit_balance, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def members_count
      object.organization_memberships.count
    end
  end
end
