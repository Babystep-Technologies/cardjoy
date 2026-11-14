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
    # Needed when the registry is protected, so item ids alone can't be used to claim from it.
    argument :passcode, String, required: false
    # The guest has already bought it: claim and mark bought in one step, so the claim never goes
    # stale (#309).
    argument :already_purchased, Boolean, required: false, default_value: false

    field :reservation, Types::WishListReservationType, null: true
    field :token, String, null: true
    field :wish_list_item, Types::WishListItemType, null: true
    field :errors, [ String ], null: false

    def resolve(wish_list_item_id:, guest_name:, guest_email:, quantity: 1, passcode: nil, already_purchased: false)
      item = WishListItem.find_by(id: wish_list_item_id)
      return failure("Item not found") unless item
      return failure("That passcode isn't right") unless item.wish_list.open_to?(context[:current_user], passcode)
      return failure("This registry's event has passed, so it is closed to new claims") if item.wish_list.archived?

      reservation = nil
      item.with_lock do
        if quantity > item.remaining_quantity
          message = item.remaining_quantity.zero? ? "This item is already fully claimed" : "Only #{item.remaining_quantity} left to claim"
          return failure(message)
        end

        reservation = item.reservations.create(
          guest_name: guest_name, guest_email: guest_email, quantity: quantity,
          purchased_at: already_purchased ? Time.current : nil
        )
        return failure(*reservation.errors.full_messages) unless reservation.persisted?
      end

      WishListMailer.claim_confirmation(reservation).deliver_later

      { reservation: reservation, token: reservation.token, wish_list_item: item.reload, errors: [] }
    end

    private

    def failure(*messages)
      { reservation: nil, token: nil, wish_list_item: nil, errors: messages }
    end
  end
end
