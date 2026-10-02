# typed: true
# frozen_string_literal: true

module Types
  class WishListLinkPreviewType < Types::BaseObject
    field :title, String, null: false
    field :image_url, String, null: true
    field :price, String, null: true
    field :store, String, null: true
  end
end
