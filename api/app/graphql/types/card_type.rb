# typed: true

module Types
  class CardType < Types::BaseObject
    field :id, ID, null: false
    field :external_id, String, null: false
    field :slug, String, null: true
    field :qr_code_url, String, null: true
    field :title, String, null: false
    field :kind, String, null: false
    field :locked, Boolean, null: false
    field :flagged, Boolean, null: false
    field :deleted, Boolean, null: false
    field :description, String, null: true
    field :contributor_prompt, String, null: true
    field :occasion, String, null: true
    field :styles, [ Types::StyleType ], null: false
    field :user, Types::UserType, null: false
    field :recipients, [ String ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :deliver_at, GraphQL::Types::ISO8601DateTime, null: true
    field :deliver_to_email, String, null: true
    field :cover_image_url, String, null: true
    field :message_limit_reached, Boolean, null: false
    field :max_messages, Integer, null: false
    field :require_login_to_contribute, Boolean, null: false

    field :messages, [ Types::MessageType ], null: true
    def messages
      if context[:show_flagged_messages]
        object.messages
      else
        object.messages.not_flagged
      end
    end

    field :guest_messages, [ Types::GuestMessageType ], null: true
    def guest_messages
      if context[:show_flagged_messages]
        object.guest_messages
      else
        object.guest_messages.not_flagged
      end
    end
  end
end
