# typed: true
# frozen_string_literal: true

module Queries
  # One holiday card, read as internal staff rather than as its owner (#178).
  #
  # Queries::HolidayCard resolves through `user.holiday_cards`, and an admin JWT
  # carries `admin_id` with no `current_user` at all — a token is either a user
  # or an admin, never both. So that query cannot serve admin: staff literally
  # could not open any customer's holiday card, which is also why we could not
  # act on an abuse report about one.
  #
  # Unscoped, so an archived card is still readable. That is the point: the
  # detail view is where staff check what they archived, and unarchiving it from
  # the list means having seen it.
  class AdminHolidayCard < Queries::BaseQuery
    type Types::HolidayCardType, null: true
    argument :external_id, String, required: true

    def resolve(external_id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ::HolidayCard.unscope(where: :deleted_at).find_by(external_id: external_id)
    end
  end
end
