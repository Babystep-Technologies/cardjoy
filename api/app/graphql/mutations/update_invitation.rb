# typed: false
# frozen_string_literal: true

module Mutations
  class UpdateInvitation < BaseMutation
    argument :external_id, String, required: true
    argument :title, String, required: false
    argument :description, String, required: false
    argument :location, String, required: false
    argument :event_date, GraphQL::Types::ISO8601Date, required: false
    argument :event_time, String, required: false
    argument :event_timezone, String, required: false
    argument :rsvp_deadline, GraphQL::Types::ISO8601Date, required: false
    argument :cover_image_file, ApolloUploadServer::Upload, required: false
    argument :cover_image_url, String, required: false
    argument :max_additional_guests, Integer, required: false
    argument :attire, String, required: false
    argument :custom_instructions, String, required: false
    argument :opening_message, String, required: false
    argument :opening_message_config, Types::OpeningMessageConfigInputType, required: false
    argument :slug, String, required: false

    field :invitation, Types::InvitationType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:, **attributes)
      user = context[:current_user]
      return { invitation: nil, errors: [ "You must be signed in" ] } unless user

      # Looked up globally and then authorized, rather than scoped to the
      # caller's own invitations, so an admin of the owning organization can
      # edit one a colleague created. See OrganizationScoped#editable_by?.
      invitation = Invitation.find_by(external_id: external_id)
      return { invitation: nil, errors: [ "Invitation not found" ] } unless invitation&.editable_by?(user)

      # Validate and format event_time if provided
      if attributes[:event_time].present?
        formatted_time = format_time(attributes[:event_time])
        return { invitation: nil, errors: [ "Event time must be in HH:MM format (e.g., 14:00)" ] } unless formatted_time
        attributes[:event_time] = formatted_time
      end

      # Handle cover image update
      if attributes[:cover_image_file].present? && attributes[:cover_image_file].respond_to?(:to_io)
        invitation.cover_image.attach(io: attributes[:cover_image_file].to_io, filename: attributes[:cover_image_file].original_filename)
      elsif attributes[:cover_image_url].present?
        cover_url = attributes[:cover_image_url]
        # Skip if it's the current cover image URL (already attached) or a Rails blob URL
        unless cover_url == invitation.cover_image_url || cover_url.include?("/rails/active_storage/")
          downloaded_file = URI.open(cover_url)
          uri = URI.parse(cover_url)
          filename = File.basename(T.must(uri.path))
          invitation.cover_image.attach(io: downloaded_file, filename: filename)
        end
      end

      # Always remove file-related attributes as they're not model attributes
      attributes.delete(:cover_image_file)
      attributes.delete(:cover_image_url)

      # Convert opening_message_config to hash if present
      if attributes[:opening_message_config].present?
        attributes[:opening_message_config] = attributes[:opening_message_config].to_h
      end

      # Remove nil values
      attributes.compact!

      Rails.logger.info "UpdateInvitation: Updating invitation #{external_id} with attributes: #{attributes.keys}"

      if invitation.update(attributes)
        Rails.logger.info "UpdateInvitation: Successfully updated invitation #{external_id}"

        # Send update notifications to all RSVPs who are going or maybe (async)
        NotifyRsvpsOfUpdateJob.perform_later(invitation.id)

        { invitation: invitation.reload, errors: [] }
      else
        Rails.logger.error "UpdateInvitation: Failed to update invitation #{external_id}: #{invitation.errors.full_messages}"
        { invitation: nil, errors: invitation.errors.full_messages }
      end
    rescue OpenURI::HTTPError => e
      { invitation: nil, errors: [ "Failed to download cover image: #{e.message}" ] }
    rescue StandardError => e
      { invitation: nil, errors: [ e.message ] }
    end

    private

    def format_time(time_string)
      return nil if time_string.blank?

      # Try to parse the time string and format it as HH:MM
      # Accepts formats like "14:00", "2:00 PM", "14:00:00"
      time = Time.parse(time_string)
      time.strftime("%H:%M")
    rescue ArgumentError
      nil
    end
  end
end
