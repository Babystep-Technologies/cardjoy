# typed: true
# frozen_string_literal: true

module Types
  class WishListItemType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false
    field :url, String, null: true
    field :image_url, String, null: true
    field :price, String, null: true
    field :store, String, null: true
    field :note, String, null: true
    field :quantity, Integer, null: false
    field :position, Integer, null: false
  end
end
