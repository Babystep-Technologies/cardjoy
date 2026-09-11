# typed: true

module Types
  class SupportTicketMessageType < Types::BaseObject
    description "One message in a support ticket's thread."

    field :id, ID, null: false
    field :author_kind, String, null: false,
      description: "\"customer\", \"admin\", or \"system\"."
    field :author_id, ID, null: true,
      description: "A user id when authorKind is \"customer\", an admin id when \"admin\", null for \"system\"."
    field :author_name, String, null: true,
      description: "The customer's or admin's name, resolved from authorKind + authorId. Null for \"system\"."
    field :author_email, String, null: true,
      description: "The customer's or admin's email, resolved from authorKind + authorId. Null for \"system\"."
    field :body, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # User and Admin are separate models with separate id spaces (see
    # SupportTicketMessage), so author_id alone can't be resolved without
    # knowing author_kind first — there is no association to eager-load
    # instead. A ticket's thread is small and bounded, unlike the admin list
    # this type is also used from, so resolving each message's author here
    # costs at most one query per message rather than one per page.
    def author_name
      author&.name
    end

    def author_email
      author&.email
    end

    private

    def author
      case object.author_kind
      when SupportTicketMessage::CUSTOMER
        User.find_by(id: object.author_id)
      when SupportTicketMessage::ADMIN
        Admin.find_by(id: object.author_id)
      end
    end
  end
end
