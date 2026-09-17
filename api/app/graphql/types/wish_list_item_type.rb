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
    field :reserved_quantity, Integer, null: false
    field :remaining_quantity, Integer, null: false
    field :claimed, Boolean, null: false
    field :reservations, [ Types::WishListReservationType ], null: false

    def reserved_quantity
      object.reserved_quantity
    end

    def remaining_quantity
      object.remaining_quantity
    end

    def claimed
      object.claimed?
    end

    # Who reserved what stays hidden from everyone except the host, and even the host only sees it
    # when they've turned surprise mode off (WishList#surprise_mode) -- otherwise a guest browsing
    # the list, or a host peeking at their own invitation, would spoil the surprise.
    def reservations
      wish_list = object.wish_list
      return [] if wish_list.surprise_mode

      viewer = context[:current_user]
      return [] unless viewer && viewer.id == wish_list.invitation.user_id

      object.reservations
    end
  end
end
