# typed: false
# frozen_string_literal: true

module Mutations
  # Public/unauthenticated, like reserve and release: the token is the only proof the caller is the
  # guest who claimed the item. Marks a claim as actually bought (or takes that back), which is what
  # protects it from being released as stale (#248).
  class SetWishListReservationPurchased < BaseMutation
    argument :token, String, required: true
    argument :purchased, Boolean, required: false, default_value: true

    field :wish_list_item, Types::WishListItemType, null: true
    field :errors, [ String ], null: false

    def resolve(token:, purchased:)
      reservation = WishListReservation.find_by(token: token)
      return { wish_list_item: nil, errors: [ "Reservation not found" ] } unless reservation

      reservation.update!(purchased_at: purchased ? (reservation.purchased_at || Time.current) : nil)
      { wish_list_item: reservation.wish_list_item.reload, errors: [] }
    end
  end
end
