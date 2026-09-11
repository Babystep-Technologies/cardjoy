# typed: true

module Queries
  # This year's (or a chosen year's) dashboard targets (#183). Null when no
  # goal has been set for that year yet — the same "not configured" shape the
  # dashboard already branches on, now server-side instead of a missing
  # localStorage key.
  class AdminAnnualGoals < BaseQuery
    type Types::AnnualGoalType, null: true

    argument :year, Integer, required: false, description: "Defaults to the current calendar year."

    def resolve(year: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ::AnnualGoal.find_by(year: year || Date.current.year)
    end
  end
end
