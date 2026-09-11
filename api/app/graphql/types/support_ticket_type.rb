# typed: true

module Types
  class SupportTicketType < Types::BaseObject
    description "A customer's support conversation."

    field :id, ID, null: false
    field :external_id, String, null: false,
      description: "The id used in URLs and in email subjects."
    field :subject, String, null: false
    field :category, String, null: false
    field :status, String, null: false,
      description: "\"open\", \"pending\", \"resolved\", or \"closed\"."
    field :last_customer_reply_at, GraphQL::Types::ISO8601DateTime, null: true
    field :last_admin_reply_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :messages, [ Types::SupportTicketMessageType ], null: false
    # Shared with the customer's own reads (mySupportTickets, supportTicket) as
    # well as the admin inbox (#173) — the ticket's customer and any assignment
    # are not sensitive to the customer whose own ticket this is.
    field :customer, Types::UserType, null: false
    field :assigned_admin, Types::AdminType, null: true
    field :status_updated_by, Types::AdminType, null: true

    def customer
      object.user
    end

    def assigned_admin
      object.assigned_admin
    end

    def status_updated_by
      object.status_updated_by_admin
    end
  end
end
