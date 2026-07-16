# typed: true

module Types
  class GuestMessageType < Types::BaseObject
    field :id, ID, null: false
    # All nullable to match their columns — see Types::MessageType#title.
    field :name, String, null: true
    field :flagged, Boolean, null: false
    field :title, String, null: true
    field :text, String, null: true
    field :image_url, String, null: true
    field :reacted_user_ids, [ ID ], null: false
    field :kind, String, null: false

    def reacted_user_ids
      object.reacted_user_ids
    end

    def kind
      object.class.name
    end
  end
end
