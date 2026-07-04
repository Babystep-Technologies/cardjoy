# typed: true
# frozen_string_literal: true

module Types
  class CollectionType < Types::BaseObject
    field :id, ID, null: false
    field :name, String
    field :description, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :styles, [ Types::StyleType ], null: true
  end
end
