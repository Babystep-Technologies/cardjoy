# typed: true

module Queries
  class UpcomingOccasions < BaseQuery
    type [ Types::OccasionType ], null: false

    argument :within_days, Integer, required: false, default_value: 30

    def resolve(within_days: 30)
      user = context[:current_user]
      return [] unless user

      Occasion.upcoming(user:, within_days:)
    end
  end
end
