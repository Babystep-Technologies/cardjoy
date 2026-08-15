# typed: true
# frozen_string_literal: true

module Queries
  # Fetch one of the caller's own holiday cards by its `external_id`.
  #
  # Unlike Queries::Card this is not a public read — a holiday card is a private
  # draft until it is printed, so it is scoped to the owner. Someone else's card
  # returns nil rather than an error, which is the same answer as an id that
  # does not exist: a caller can't use this to learn which cards exist.
  class HolidayCard < BaseQuery
    type Types::HolidayCardType, null: true
    argument :external_id, String, required: true

    def resolve(external_id:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.holiday_cards.find_by(external_id: external_id)
    end
  end
end
