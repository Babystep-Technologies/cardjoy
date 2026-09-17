# typed: false
# frozen_string_literal: true

module Mutations
  # Public/unauthenticated, mirroring Mutations::ReserveWishListItem. The token is the only proof of
  # ownership -- there's no guest account to check against.
  class ReleaseWishListReservation < BaseMutation
    argument :token, String, required: true

    field :wish_list_item, Types::WishListItemType, null: true
    field :errors, [ String ], null: false

    def resolve(token:)
      reservation = WishListReservation.find_by(token: token)
      return { wish_list_item: nil, errors: [ "Reservation not found" ] } unless reservation

      item = reservation.wish_list_item
      reservation.destroy!
      { wish_list_item: item.reload, errors: [] }
    end
  end
end
