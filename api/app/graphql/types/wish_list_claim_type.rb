# typed: true
# frozen_string_literal: true

module Types
  # What a guest's own claim looks like to them, read back with the token from their email. Carries
  # no names, emails or anyone else's claims.
  class WishListClaimType < Types::BaseObject
    field :wish_list_item_id, ID, null: false
    field :purchased, Boolean, null: false, method: :purchased?
  end
end
