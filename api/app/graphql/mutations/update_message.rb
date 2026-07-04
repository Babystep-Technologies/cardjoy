# typed: false

module Mutations
  class UpdateMessage < BaseMutation
    argument :message_id, ID, required: true
    argument :text, String, required: false
    argument :image_url, String, required: false

    field :message, Types::MessageType, null: true
    field :errors, [ String ], null: false

    def resolve(message_id:, text: nil, image_url: nil)
      user = context[:current_user]
      return { message: nil, errors: [ "Not authenticated" ] } unless user

      message = Message.find_by(id: message_id, user: user)
      return { message: nil, errors: [ "Message not found or not owned by user" ] } unless message

      # Update fields if provided
      message.text = text if text.present?
      message.image_url = image_url if image_url.present?

      if message.save
        { message: message, errors: [] }
      else
        { message: nil, errors: message.errors.full_messages }
      end
    end
  end
end
