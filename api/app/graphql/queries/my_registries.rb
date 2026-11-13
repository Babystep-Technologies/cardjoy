# typed: true

module Queries
  # The caller's own registries, newest first, for the dashboard (#245). Includes the ones that
  # hang off an invitation, so everything the user has asked for is in one list.
  class MyRegistries < BaseQuery
    type [ Types::WishListType ], null: false

    def resolve
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.wish_lists.includes(:items, :contributions).order(created_at: :desc)
    end
  end
end
