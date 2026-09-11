# typed: true

module Queries
  # Fetch one of the caller's own support tickets by its `external_id`.
  #
  # Mirrors Queries::HolidayCard: someone else's ticket and one that never
  # existed both return nil, so a caller can't use this to learn which
  # external ids are real.
  class SupportTicket < BaseQuery
    type Types::SupportTicketType, null: true
    argument :external_id, String, required: true

    def resolve(external_id:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.support_tickets.find_by(external_id:)
    end
  end
end
