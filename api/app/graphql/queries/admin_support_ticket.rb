# typed: true

module Queries
  # One ticket's full thread for the admin inbox (#173): every message in
  # order, the customer, and who — if anyone — is working it.
  #
  # Unlike Queries::SupportTicket, this is not scoped to a user, because staff
  # look up tickets that are never their own.
  class AdminSupportTicket < BaseQuery
    type Types::SupportTicketType, null: true

    argument :external_id, String, required: true

    def resolve(external_id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ::SupportTicket.find_by(external_id:)
    end
  end
end
