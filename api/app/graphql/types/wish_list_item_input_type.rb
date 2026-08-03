# typed: true
# frozen_string_literal: true

module Types
  class WishListItemInputType < Types::BaseInputObject
    argument :title, String, required: true
    argument :url, String, required: false
    argument :image_url, String, required: false
    argument :price, String, required: false
    argument :store, String, required: false
    argument :note, String, required: false
    argument :quantity, Integer, required: false, default_value: 1
  end
end
