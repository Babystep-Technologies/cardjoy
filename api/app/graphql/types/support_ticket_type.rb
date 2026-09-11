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
  end
end
