# typed: true

module Types
  class DailyMetricsType < Types::BaseObject
    field :date, String, null: false
    field :users, Integer, null: false
    field :cards, Integer, null: false
    field :invitations, Integer, null: false
    field :rsvps, Integer, null: false
  end
end
