# typed: true

module Types
  # One day of Types::AdminMetricsType#dailySeries (#183) — every series the
  # dashboard charts, for one calendar date.
  class AdminMetricsDailyPointType < Types::BaseObject
    field :date, GraphQL::Types::ISO8601Date, null: false

    # Distinct users who made an authenticated request this day, and the
    # trailing 7-day average of that — the two lines the DAU chart overlays.
    # A day before Types::AdminMetricsType#dauBackfillBoundary is backfilled
    # from creation timestamps rather than real request tracking; the client
    # marks that range using the boundary date, not a per-point flag.
    field :dau, Integer, null: false
    field :dau_rolling_7d, Float, null: false

    field :new_users, Integer, null: false
    field :group_cards, Integer, null: false
    field :one_on_one_cards, Integer, null: false
    field :invitations, Integer, null: false
    field :holiday_cards, Integer, null: false
    field :rsvps, Integer, null: false
  end
end
