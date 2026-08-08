# typed: true

module Types
  class OrganizationMembershipType < Types::BaseObject
    field :id, ID, null: false
    field :role, String, null: false
    field :user, Types::UserType, null: false
    field :organization, Types::OrganizationType, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
