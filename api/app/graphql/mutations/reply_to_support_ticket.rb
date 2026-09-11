# typed: true
# frozen_string_literal: true

module Mutations
  # Appends a customer reply to their own support ticket (#172).
  #
  # A stranger's `ticketExternalId` and one that never existed get the exact
  # same "not found" error — never NOT_AUTHORIZED_ERROR — so a caller can't
  # use this to learn which ticket ids are real. `user.support_tickets.find_by`
  # already returns nil for both, which is what makes the two indistinguishable
  # here without any extra work.
  class ReplyToSupportTicket < BaseMutation
    NOT_FOUND_ERROR = "Support ticket not found"

    argument :ticket_external_id, String, required: true
    argument :body, String, required: true

    field :support_ticket, Types::SupportTicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_external_id:, body:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      ticket = user.support_tickets.find_by(external_id: ticket_external_id)
      return failure(NOT_FOUND_ERROR) unless ticket

      ticket.record_customer_reply!(user:, body:)

      { support_ticket: ticket, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def failure(errors)
      { support_ticket: nil, errors: Array(errors) }
    end
  end
end
