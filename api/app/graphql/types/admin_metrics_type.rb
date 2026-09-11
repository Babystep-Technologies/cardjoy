# typed: true

module Types
  # The metrics dashboard's one response type (#183): window totals plus a
  # daily series for charting, replacing the old fixed-window
  # Types::BusinessMetricsType (kept alive, unchanged, until the dashboard has
  # migrated — see Queries::AdminMetrics).
  class AdminMetricsType < Types::BaseObject
    field :window, Types::MetricsWindowType, null: false
    field :start_date, GraphQL::Types::ISO8601Date, null: false
    field :end_date, GraphQL::Types::ISO8601Date, null: false

    # Per-product creation totals for the window. Cards are split by kind for
    # the first time (#177 added the column; nothing before this grouped on
    # it), and holiday cards are counted at all for the first time.
    field :new_users, Integer, null: false
    field :group_cards, Integer, null: false
    field :one_on_one_cards, Integer, null: false
    field :invitations, Integer, null: false
    field :holiday_cards, Integer, null: false

    field :rsvps_going, Integer, null: false
    field :rsvps_maybe, Integer, null: false
    field :rsvps_not_going, Integer, null: false
    field :total_attendees, Integer, null: false

    # The goal card's DAU figure: the 7-day rolling average as of the most
    # recent day in the window, not a raw single-day count — matching the
    # card's own "7-day rolling" label for the first time (it used to read
    # newUsers over the last 7 days, a different metric entirely).
    field :current_dau_rolling_7d, Float, null: false

    # Everything on or after this date is real request-tracked DAU; everything
    # before it is backfilled from creation timestamps (#182), a narrower,
    # different metric — UserDailyActivity::BACKFILL_CUTOFF_ON, a fixed
    # constant rather than data, so this is never null even before the
    # backfill rake task has run in a given environment.
    field :dau_backfill_boundary, GraphQL::Types::ISO8601Date, null: false

    field :daily_series, [ Types::AdminMetricsDailyPointType ], null: false
  end
end
