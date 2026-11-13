# typed: true
# frozen_string_literal: true

module Types
  # Aggregate progress on a registry, for its owner only (#252). Counts, never people: nothing here
  # says who claimed or bought what, so it is safe to show with surprise mode on.
  class WishListInsightsType < Types::BaseObject
    field :item_count, Integer, null: false
    # Items whose full quantity has been claimed.
    field :covered_count, Integer, null: false
    # Claims the guest has marked as bought.
    field :purchased_count, Integer, null: false
  end
end
