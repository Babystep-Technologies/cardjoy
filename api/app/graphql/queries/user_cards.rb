# typed: true

module Queries
  class UserCards < BaseQuery
    type [ Types::CardType ], null: true
    argument :user_id, ID, required: true

    def resolve(user_id:)
      user = context[:current_user] # Ensure user authentication
      return [] unless user
      user = ::User.find_by(id: user_id)
      return [] unless user

      user.cards
    end
  end
end
