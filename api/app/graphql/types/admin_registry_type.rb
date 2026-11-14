# typed: true
# frozen_string_literal: true

module Types
  # A registry as the admin list sees it (#317): operational facts only. Deliberately not
  # WishListType, which carries owner-facing and guest-facing data (claimers, address, passcode state).
  class AdminRegistryType < Types::BaseObject
    field :id, ID, null: false
    field :external_id, String, null: false
    field :title, String, null: false
    field :occasion, String, null: true
    field :event_date, GraphQL::Types::ISO8601Date, null: true
    field :visible, Boolean, null: false
    field :archived, Boolean, null: false, method: :archived?
    field :passcode_protected, Boolean, null: false, method: :passcode_protected?
    field :user, Types::UserType, null: false
    field :item_count, Integer, null: false
    field :claim_count, Integer, null: false
    field :purchased_count, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def item_count = object.items.size

    def claim_count = reservations.size

    def purchased_count = reservations.count { |reservation| reservation.purchased_at.present? }

    private

    def reservations
      object.items.flat_map(&:reservations)
    end
  end
end
