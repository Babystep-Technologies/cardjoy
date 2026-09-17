# typed: true
# frozen_string_literal: true

module Types
  class WishListItemInputType < Types::BaseInputObject
    # Omitted for a new item; pass back an existing item's id to update it in place instead of
    # replacing it, so reservations against that item (WishListReservation) survive the edit.
    argument :id, ID, required: false
    argument :title, String, required: true
    argument :url, String, required: false
    argument :image_url, String, required: false
    argument :price, String, required: false
    argument :store, String, required: false
    argument :note, String, required: false
    argument :quantity, Integer, required: false, default_value: 1
  end
end
