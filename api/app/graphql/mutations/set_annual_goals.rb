# typed: true

module Mutations
  # Sets (or replaces) one year's dashboard targets (#183). Upserts on `year`
  # rather than taking an id — the client always means "this year's goal",
  # never a specific row it has to have fetched first.
  class SetAnnualGoals < Mutations::BaseMutation
    argument :year, Integer, required: true
    argument :dau_target, Integer, required: true
    argument :cards_and_invitations_target, Integer, required: true

    field :annual_goal, Types::AnnualGoalType, null: true
    field :errors, [ String ], null: false

    def resolve(year:, dau_target:, cards_and_invitations_target:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      goal = ::AnnualGoal.find_or_initialize_by(year: year)
      goal.update!(dau_target: dau_target, cards_and_invitations_target: cards_and_invitations_target)

      { annual_goal: goal, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      { annual_goal: nil, errors: e.record.errors.full_messages }
    end
  end
end
