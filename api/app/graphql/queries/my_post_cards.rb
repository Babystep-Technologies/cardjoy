# typed: true
# frozen_string_literal: true

module Queries
  # The signed-in user's post cards, newest first.
  #
  # Unlike Queries::UserCards there is no `organizationId` argument: post
  # cards are deliberately personal for now (see the epic's decision table), so
  # the scope is always the caller.
  class MyPostCards < BaseQuery
    type [ Types::PostCardType ], null: false

    def resolve
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.post_cards.order(created_at: :desc)
    end
  end
end
