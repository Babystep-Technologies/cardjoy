# typed: true

module Types
  class SupportTicketMessageType < Types::BaseObject
    description "One message in a support ticket's thread."

    field :id, ID, null: false
    field :author_kind, String, null: false,
      description: "\"customer\", \"admin\", or \"system\"."
    field :author_id, ID, null: true,
      description: "A user id when authorKind is \"customer\", an admin id when \"admin\", null for \"system\"."
    field :body, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
