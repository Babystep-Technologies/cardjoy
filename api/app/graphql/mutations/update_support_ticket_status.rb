# typed: true
# frozen_string_literal: true

module Mutations
  # A plain status change with no accompanying reply (#173) — e.g. closing a
  # ticket the customer never replied back to, or reopening one by hand.
  # Records status_updated_by_admin, the same way assignSupportTicket records
  # itself in assigned_admin.
  class UpdateSupportTicketStatus < BaseMutation
    NOT_FOUND_ERROR = "Support ticket not found"
    INVALID_STATUS_ERROR = "Invalid status"

    argument :ticket_external_id, String, required: true
    argument :status, String, required: true

    field :support_ticket, Types::SupportTicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_external_id:, status:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ticket = ::SupportTicket.find_by(external_id: ticket_external_id)
      return failure(NOT_FOUND_ERROR) unless ticket
      return failure(INVALID_STATUS_ERROR) unless ::SupportTicket::STATUSES.include?(status)

      ticket.update_status_by_admin!(admin:, status:)

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
