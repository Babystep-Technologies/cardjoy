# typed: true
# frozen_string_literal: true

module Types
  # Host-facing view of a claim on a WishListItem. Deliberately omits guest_email and token: email
  # isn't needed to see "who's bringing what", and the token is a bearer secret that must never be
  # retrievable except from the reserve mutation's own response.
  class WishListReservationType < Types::BaseObject
    field :id, ID, null: false
    field :guest_name, String, null: false
    field :quantity, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
