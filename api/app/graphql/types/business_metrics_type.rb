# typed: true

module Types
  class BusinessMetricsType < Types::BaseObject
    field :users_last_1_day, Integer, null: false
    field :users_last_7_days, Integer, null: false
    field :users_last_30_days, Integer, null: false
    field :users_last_90_days, Integer, null: false
    field :users_last_180_days, Integer, null: false

    field :cards_last_1_day, Integer, null: false
    field :cards_last_7_days, Integer, null: false
    field :cards_last_30_days, Integer, null: false
    field :cards_last_90_days, Integer, null: false
    field :cards_last_180_days, Integer, null: false

    # Invitation creation metrics
    field :invitations_last_1_day, Integer, null: false
    field :invitations_last_7_days, Integer, null: false
    field :invitations_last_30_days, Integer, null: false
    field :invitations_last_90_days, Integer, null: false
    field :invitations_last_180_days, Integer, null: false

    # RSVP metrics
    field :rsvps_last_1_day, Integer, null: false
    field :rsvps_last_7_days, Integer, null: false
    field :rsvps_last_30_days, Integer, null: false
    field :rsvps_last_90_days, Integer, null: false
    field :rsvps_last_180_days, Integer, null: false

    # RSVP engagement breakdown (30 days)
    field :rsvps_going_last_30_days, Integer, null: false
    field :rsvps_maybe_last_30_days, Integer, null: false
    field :rsvps_not_going_last_30_days, Integer, null: false
    field :total_attendees_last_30_days, Integer, null: false
  end
end
