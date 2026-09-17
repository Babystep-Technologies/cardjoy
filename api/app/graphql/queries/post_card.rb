# typed: true
# frozen_string_literal: true

module Queries
  # Fetch one of the caller's own post cards by its `external_id`.
  #
  # Unlike Queries::Card this is not a public read — a post card is a private
  # draft until it is printed, so it is scoped to the owner. Someone else's card
  # returns nil rather than an error, which is the same answer as an id that
  # does not exist: a caller can't use this to learn which cards exist.
  class PostCard < BaseQuery
    type Types::PostCardType, null: true
    argument :external_id, String, required: true

    def resolve(external_id:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.post_cards.find_by(external_id: external_id)
    end
  end
end
