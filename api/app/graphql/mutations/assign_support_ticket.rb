# typed: true
# frozen_string_literal: true

module Mutations
  # Hands a ticket to a specific staff member (#173) so the inbox can be
  # divided up rather than every admin working from the same unfiltered list.
  class AssignSupportTicket < BaseMutation
    NOT_FOUND_ERROR = "Support ticket not found"
    ADMIN_NOT_FOUND_ERROR = "Admin not found"

    argument :ticket_external_id, String, required: true
    argument :admin_id, ID, required: true

    field :support_ticket, Types::SupportTicketType, null: true
    field :errors, [ String ], null: false

    def resolve(ticket_external_id:, admin_id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ticket = ::SupportTicket.find_by(external_id: ticket_external_id)
      return failure(NOT_FOUND_ERROR) unless ticket

      assignee = ::Admin.find_by(id: admin_id)
      return failure(ADMIN_NOT_FOUND_ERROR) unless assignee

      ticket.assign_to!(admin: assignee)

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
