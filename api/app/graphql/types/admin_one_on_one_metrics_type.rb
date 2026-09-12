# typed: true

module Types
  # The 1-on-1 product's north-star metrics (#30), windowed the same way
  # Types::AdminMetricsType is. Four ratios, each with the counts behind it so
  # the dashboard can show "12 / 340" rather than just "3.5%":
  #
  # - creationCompletionRate: oneOnOneCardsCreated / flowStarts
  # - occasionsSavedPerUser: occasionsSaved / usersWithOccasions
  # - reminderConversionRate: cardsFromReminder / remindersSent
  # - crossOverRate: crossedOverToGroupCard / oneOnOneSenders
  #
  # Every rate is 0.0, not NaN or null, when its denominator is zero.
  class AdminOneOnOneMetricsType < Types::BaseObject
    field :window, Types::MetricsWindowType, null: false
    field :start_date, GraphQL::Types::ISO8601Date, null: false
    field :end_date, GraphQL::Types::ISO8601Date, null: false

    # Creation completion rate. `flowStarts` only counts from this feature's
    # ship date forward (Mutations::TrackOneOnOneFlowStart) — there is no
    # historical data to backfill it from.
    field :flow_starts, Integer, null: false
    field :one_on_one_cards_created, Integer, null: false
    field :creation_completion_rate, Float, null: false

    # Occasions saved per (active) user: occasions added in the window, over
    # the distinct users who added at least one.
    field :occasions_saved, Integer, null: false
    field :users_with_occasions, Integer, null: false
    field :occasions_saved_per_user, Float, null: false

    # Reminder to card conversion. `remindersSent` counts occasions whose
    # `last_reminded_at` falls in the window — an approximation when the same
    # occasion is reminded for two different occurrences inside one window
    # (only the latest send is retained), which is rare at 30/90-day windows.
    field :reminders_sent, Integer, null: false
    field :cards_from_reminder, Integer, null: false
    field :reminder_conversion_rate, Float, null: false

    # Cross-over: of the users whose *first ever* 1-on-1 card falls in this
    # window, how many have since created a group card.
    field :one_on_one_senders, Integer, null: false
    field :crossed_over_to_group_card, Integer, null: false
    field :cross_over_rate, Float, null: false
  end
end
