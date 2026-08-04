# typed: true
# frozen_string_literal: true

module Types
  class WishListType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :intro, String, null: true
    field :visible, Boolean, null: false
    field :surprise_mode, Boolean, null: false
    field :items, [ Types::WishListItemType ], null: false
    field :contributions, [ Types::WishListContributionType ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
