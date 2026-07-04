# typed: true

module Mutations
  class ReactToMessage < BaseMutation
    argument :message_id, ID, required: true
    argument :message_type, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false
    field :message_id, ID, null: true
    field :message_type, String, null: true

    def resolve(message_id:, message_type:)
      user = context[:current_user] # Ensure user authentication
      return error_response("Not authenticated") unless user

      message_model = case message_type
      when "Message"
        ::Message
      when "GuestMessage"
        ::GuestMessage
      else
        return error_response("Invalid message type")
      end

      message = message_model.find_by(id: message_id)
      return error_response("Message not found") unless message

      message.toggle_reaction!(user.id)

      { message_id: message.id, message_type: message_type, success: true, errors: [] }
    end

    private
    def error_response(message)
      {
        success: false,
        errors: [ message ],
        message_id: nil,
        message_type: nil
      }
    end
  end
end
