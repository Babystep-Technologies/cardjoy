# typed: true
# frozen_string_literal: true

module Mutations
  # Starts a support ticket (#172): the ticket and its first customer message
  # are created atomically, so a ticket can never exist with no thread to show
  # for it. Replaces the fire-and-forget email Mutations::CreateSupportRequest
  # sent, which stays working but deprecated until #175 ships the UI that
  # calls this instead.
  class CreateSupportTicket < BaseMutation
    argument :subject, String, required: true
    argument :category, String, required: true
    argument :body, String, required: true

    field :support_ticket, Types::SupportTicketType, null: true
    field :errors, [ String ], null: false

    def resolve(subject:, category:, body:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user
      return failure("Invalid category") unless SupportTicket::CATEGORIES.include?(category)

      ticket = user.support_tickets.build(
        subject:, category:, status: SupportTicket::OPEN, last_customer_reply_at: Time.current
      )

      ApplicationRecord.transaction do
        ticket.save!
        ticket.messages.create!(author_kind: SupportTicketMessage::CUSTOMER, author_id: user.id, body:)
      end

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
