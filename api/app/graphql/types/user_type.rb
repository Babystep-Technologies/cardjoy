# typed: true

module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :email, String, null: false
    field :name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :credit_balance, Integer, null: false
    field :cards_count, Integer, null: false
    field :invitations_count, Integer, null: false

    def credit_balance
      object.credits.sum(:amount)
    end

    def cards_count
      object.cards.count
    end

    def invitations_count
      object.invitations.count
    end
  end
end
