# typed: true

module Types
  class ContactType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: true
    field :relationship, String, null: true
    field :occasions, [ Types::OccasionType ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
