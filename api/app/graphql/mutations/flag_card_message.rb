# typed: true

module Mutations
  class FlagCardMessage < BaseMutation
    argument :message_id, ID, required: true
    argument :message_kind, String, required: true # "user" or "guest"

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(message_id:, message_kind:)
      admin = context[:current_admin]
      user = context[:current_user]

      klass =
        case message_kind
        when "user"
          Message
        when "guest"
          GuestMessage
        else
          return { success: false, errors: [ "Invalid message kind" ] }
        end

      message = klass.find_by(id: message_id)
      return { success: false, errors: [ "Message not found" ] } unless message

      # Allow admins or card creators to flag/unflag messages
      is_card_creator = user && message.card&.user_id == user.id
      unless admin || is_card_creator
        raise GraphQL::ExecutionError, "Not authorized"
      end

      begin
        message.flagged? ? message.unflag! : message.flag!
      rescue => e
        return { success: false, errors: [ e.message ] }
      end

      { success: true, errors: [] }
    end
  end
end
