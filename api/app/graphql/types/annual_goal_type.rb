# typed: true

module Types
  # A year's dashboard targets (#183), persisted server-side so every admin
  # sees the same numbers — the whole reason this replaced localStorage.
  class AnnualGoalType < Types::BaseObject
    field :year, Integer, null: false
    field :dau_target, Integer, null: false
    field :cards_and_invitations_target, Integer, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
