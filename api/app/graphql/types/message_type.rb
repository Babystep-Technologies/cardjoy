# typed: true

module Types
  class MessageType < Types::BaseObject
    field :id, ID, null: false
    field :text, String, null: false
    # Nullable to match the column: createOneOnOneCard writes a message with no
    # title, and nothing validates its presence.
    field :title, String, null: true
    field :flagged, Boolean, null: false
    field :image_url, String, null: true
    field :user, Types::UserType, null: false
    field :card, Types::CardType, null: false
    field :reacted_user_ids, [ ID ], null: false
    field :display_name, String, null: true
    field :kind, String, null: false

    def reacted_user_ids
      object.reacted_user_ids
    end

    def kind
      object.class.name
    end
  end
end
