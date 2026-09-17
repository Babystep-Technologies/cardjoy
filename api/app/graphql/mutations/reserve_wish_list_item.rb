# typed: false
# frozen_string_literal: true

module Mutations
  # Public/unauthenticated: a guest reserving a gift never needs a CardJoy account (see
  # GraphqlController::PUBLIC_OPERATIONS). The returned token is the guest's only way to release the
  # reservation later -- the client is responsible for holding onto it (see
  # Mutations::ReleaseWishListReservation).
  class ReserveWishListItem < BaseMutation
    argument :wish_list_item_id, ID, required: true
    argument :guest_name, String, required: true
    argument :guest_email, String, required: true
    argument :quantity, Integer, required: false, default_value: 1

    field :reservation, Types::WishListReservationType, null: true
    field :token, String, null: true
    field :wish_list_item, Types::WishListItemType, null: true
    field :errors, [ String ], null: false

    def resolve(wish_list_item_id:, guest_name:, guest_email:, quantity: 1)
      item = WishListItem.find_by(id: wish_list_item_id)
      return failure("Item not found") unless item

      reservation = nil
      item.with_lock do
        if quantity > item.remaining_quantity
          message = item.remaining_quantity.zero? ? "This item is already fully claimed" : "Only #{item.remaining_quantity} left to claim"
          return failure(message)
        end

        reservation = item.reservations.create(guest_name: guest_name, guest_email: guest_email, quantity: quantity)
        return failure(*reservation.errors.full_messages) unless reservation.persisted?
      end

      { reservation: reservation, token: reservation.token, wish_list_item: item.reload, errors: [] }
    end

    private

    def failure(*messages)
      { reservation: nil, token: nil, wish_list_item: nil, errors: messages }
    end
  end
end
