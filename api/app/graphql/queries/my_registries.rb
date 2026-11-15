# typed: true

module Queries
  # The caller's own registries, newest first, for the dashboard (#245).
  class MyRegistries < BaseQuery
    type [ Types::WishListType ], null: false

    def resolve
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.wish_lists.includes(:items, :contributions).order(created_at: :desc)
    end
  end
end
