# typed: true
# frozen_string_literal: true

module Types
  # One guest's claim, for the owner's thank-you notes (#252). Only ever returned while
  # WishList#thank_you_unlocked? is true.
  class WishListThankYouType < Types::BaseObject
    field :guest_name, String, null: false
    # Null once scrubbed, a week after the event.
    field :guest_email, String, null: true
    field :item_title, String, null: false
    field :purchased, Boolean, null: false

    def item_title
      object.wish_list_item.title
    end

    def purchased
      object.purchased_at.present?
    end
  end
end
