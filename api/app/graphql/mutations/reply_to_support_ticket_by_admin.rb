# typed: true
# frozen_string_literal: true

module Mutations
  # A staff reply to a customer's support ticket (#173): appends the message,
  # stamps last_admin_reply_at, moves the ticket to newStatus (pending by
  # default — a reply is normally the ticket going back to waiting on the
  # customer), and emails the customer.
  #
  # Gated on the internal-admin JWT, raising rather than returning an errors
  # array, matching the other internal-admin writes (see
  # Mutations::UpdateCardByAdmin).
  class ReplyToSupportTicketByAdmin < BaseMutation
    NOT_FOUND_ERROR = "Support ticket not found"
    INVALID_STATUS_ERROR = "Invalid status"

    argument :ticket_external_id, String, required: true
    argument :body, String, required: true
    argument :new_status, String, required: false,
      description: "open, pending, resolved, or closed. Defaults to pending."

    field :support_ticket, Types::SupportTicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_external_id:, body:, new_status: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ticket = ::SupportTicket.find_by(external_id: ticket_external_id)
      return failure(NOT_FOUND_ERROR) unless ticket
      if new_status.present? && !::SupportTicket::STATUSES.include?(new_status)
        return failure(INVALID_STATUS_ERROR)
      end

      message = ticket.receive_admin_reply!(admin:, body:, new_status:)
      SupportTicketMailer.admin_reply(message).deliver_later

      { support_ticket: ticket.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def failure(errors)
      { support_ticket: nil, errors: Array(errors) }
    end
  end
end
