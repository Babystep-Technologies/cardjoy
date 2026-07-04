# typed: true
# frozen_string_literal: true

require "open-uri"

module Mutations
  class UpsertMessage < BaseMutation
    argument :card_id, ID, required: true
    argument :user_id, ID, required: false
    argument :guest_name, String, required: false
    argument :title, String, required: false
    argument :text, String, required: true
    argument :image_url, String, required: false
    argument :file, ApolloUploadServer::Upload, required: false
    argument :display_name, String, required: false

    field :success, Boolean, null: false
    field :errors, [ String ], null: false
    field :message_id, ID, null: true
    field :message_type, String, null: true

    def resolve(card_id:, text:, title: nil, image_url: nil, file: nil, user_id: nil, guest_name: nil, display_name: nil)
      card = Card.find_by(external_id: card_id)
      return error_response("Card not found") unless card
      return error_response("Card is locked and cannot receive more messages") if card.locked

      attachment_io, filename = prepare_upload(file, image_url)
      return attachment_io if attachment_io.is_a?(Hash) # early return with error

      if user_id.present?
        message = card.messages.find_or_initialize_by(user_id: user_id)

        if message.new_record? && card.message_limit_reached?
          return error_response("This card has reached its maximum number of messages.")
        end

        message.title = title
        message.text = text
        message.display_name = display_name if display_name.present?
        message.image.attach(io: attachment_io, filename: filename) if attachment_io

        success = message.save
        {
          success: success,
          errors: message.errors.full_messages,
          message_id: message.id,
          message_type: message.class.name
        }

      elsif guest_name.present?
        guest_message = card.guest_messages.where(name: guest_name).first_or_initialize

        if guest_message.new_record? && card.message_limit_reached?
          return error_response("This card has reached its maximum number of messages.")
        end

        guest_message.title = title
        guest_message.text = text
        guest_message.image.attach(io: attachment_io, filename: filename) if attachment_io

        success = guest_message.save
        {
          success: success,
          errors: guest_message.errors.full_messages,
          message_id: guest_message.id,
          message_type: guest_message.class.name
        }

      else
        error_response("Authentication or guest name required")
      end
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

    def prepare_upload(file, image_url)
      return [ nil, nil ] unless file.present? || image_url.present?

      if file.present?
        buffered_file = Tempfile.new([ "upload", File.extname(file.original_filename) ])
        buffered_file.binmode
        buffered_file.write(file.read)
        buffered_file.rewind
        [ buffered_file, file.original_filename ]
      elsif image_url.present?
        begin
          downloaded_file = URI.open(image_url)
          filename = File.basename(T.must(URI.parse(image_url).path))
          [ downloaded_file, filename ]
        rescue => e
          { success: false, errors: [ "Failed to fetch remote image: #{e.message}" ], message_id: nil, message_type: nil }
        end
      end
    end
  end
end
