# typed: true
# frozen_string_literal: true

module Types
  # What a guest's own claim looks like to them, read back with the token from their email. Carries
  # no names or emails of other guests and none of their claims.
  class WishListClaimType < Types::BaseObject
    field :wish_list_item_id, ID, null: false
    field :purchased, Boolean, null: false, method: :purchased?

    # Where to send the gift. Present only while the owner has chosen to share their address on this
    # registry and has a complete one saved, and only to someone holding a claim token. Evaluated on
    # every read, so the owner switching sharing off hides it at once.
    field :ship_to_name, String, null: true
    field :ship_to, Types::ReturnAddressType, null: true

    def ship_to_name
      owner_sharing_address&.name.presence
    end

    def ship_to
      owner = owner_sharing_address
      return nil unless owner

      Rails.logger.info("[WishList] address revealed list=#{wish_list.id} reservation=#{object.id}")
      owner
    end

    private

    def wish_list
      object.wish_list_item.wish_list
    end

    def owner_sharing_address
      return nil unless wish_list.share_address

      owner = wish_list.user
      owner if owner.return_address_complete?
    end
  end
end
