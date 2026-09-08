# typed: true
# frozen_string_literal: true

module Types
  # A card's mailing history in five numbers, for the dashboard list (#153).
  #
  # It exists so the dashboard can say "40 mailed · 2 failed" without fetching
  # forty order rows per card to count them client-side. Counts only — no money,
  # no addresses; a caller that wants either asks `myHolidayCardOrders`.
  #
  # `total` is orders *placed*, so `total - failed` is what actually went into
  # the post. Rendering that subtraction is the client's business.
  class HolidayCardOrderSummaryType < Types::BaseObject
    description "How many pieces this card has been mailed as, and how they went."

    field :total, Integer, null: false,
      description: "Every order ever placed for this card. Zero means it has never been sent."
    field :in_flight, Integer, null: false,
      description: "Orders not yet at a terminal status — still queued, printing, or in the post."
    field :delivered, Integer, null: false,
      description: "Orders our print partner has reported as delivered."
    field :failed, Integer, null: false,
      description: "Orders that failed or were cancelled. Every one of these was refunded."
    field :last_ordered_at, GraphQL::Types::ISO8601DateTime, null: true,
      description: "When this card was last sent. Null if it never has been."
  end
end
