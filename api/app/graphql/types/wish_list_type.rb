# typed: true
# frozen_string_literal: true

module Types
  class WishListType < Types::BaseObject
    field :id, ID, null: false
    # The public id used in registry URLs.
    field :external_id, String, null: false
    field :occasion, String, null: true
    field :event_date, GraphQL::Types::ISO8601Date, null: true
    field :standalone, Boolean, null: false, method: :standalone?
    field :title, String, null: false
    field :intro, String, null: true
    field :visible, Boolean, null: false
    field :surprise_mode, Boolean, null: false
    # Whether guests who claim a gift can see the owner's mailing address. The address itself is
    # never on this type; it is only readable through a claim (Types::WishListClaimType#ship_to).
    field :share_address, Boolean, null: false
    field :remind_owner, Boolean, null: false
    # First name only: enough for a guest to see whose registry this is ("Sam's birthday"), without
    # putting an owner's full name on a page anyone with the link can open.
    field :owner_first_name, String, null: true
    field :items, [ Types::WishListItemType ], null: false
    field :contributions, [ Types::WishListContributionType ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def owner_first_name
      object.user&.name.to_s.split.first
    end
  end
end
