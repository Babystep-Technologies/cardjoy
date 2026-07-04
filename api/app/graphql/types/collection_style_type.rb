# typed: true
# frozen_string_literal: true

module Types
  class CollectionStyleType < Types::BaseObject
    field :id, ID, null: false
    field :collection_id, Integer, null: false
    field :style_id, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
