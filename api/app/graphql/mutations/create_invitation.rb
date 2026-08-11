# typed: true
# frozen_string_literal: true

module Mutations
  class CreateInvitation < BaseMutation
    argument :title, String, required: true
    argument :description, String, required: false
    argument :location, String, required: false
    argument :event_date, GraphQL::Types::ISO8601Date, required: true
    argument :event_time, String, required: true
    argument :event_timezone, String, required: false
    argument :rsvp_deadline, GraphQL::Types::ISO8601Date, required: false
    argument :cover_image_file, ApolloUploadServer::Upload, required: false
    argument :cover_image_url, String, required: false
    argument :max_additional_guests, Integer, required: false, default_value: 0
    argument :attire, String, required: false
    argument :custom_instructions, String, required: false
    argument :opening_message, String, required: false
    argument :opening_message_config, Types::OpeningMessageConfigInputType, required: false
    argument :slug, String, required: false
    # Blank means Personal. Validated below rather than read from the user's
    # active_organization_id: the client owns the context, the server checks it.
    argument :organization_id, ID, required: false

    field :invitation, Types::InvitationType, null: true
    field :errors, [ String ], null: false

    def resolve(
      title:,
      event_date:,
      event_time:,
      description: nil,
      location: nil,
      event_timezone: nil,
      rsvp_deadline: nil,
      cover_image_file: nil,
      cover_image_url: nil,
      max_additional_guests: 0,
      attire: nil,
      custom_instructions: nil,
      opening_message: nil,
      opening_message_config: nil,
      slug: nil,
      organization_id: nil
    )
      user = context[:current_user]
      return { invitation: nil, errors: [ "You must be signed in" ] } unless user

      # Checked before the transaction opens, so a create into an organization
      # the caller doesn't belong to spends no credit.
      organization = writable_organization(organization_id)
      return { invitation: nil, errors: [ NOT_AUTHORIZED_ERROR ] } if organization == false

      # Validate and format event_time to HH:MM military time format
      formatted_time = format_time(event_time)
      return { invitation: nil, errors: [ "Event time must be in HH:MM format (e.g., 14:00)" ] } unless formatted_time

      invitation = user.invitations.build(
        title: title,
        description: description,
        location: location,
        event_date: event_date,
        event_time: formatted_time,
        event_timezone: event_timezone,
        rsvp_deadline: rsvp_deadline,
        max_additional_guests: max_additional_guests,
        attire: attire,
        custom_instructions: custom_instructions,
        opening_message: opening_message,
        opening_message_config: opening_message_config&.to_h,
        external_id: SecureRandom.uuid,
        slug: slug,
        organization: organization
      )

      return { invitation: nil, errors: invitation.errors.full_messages } unless invitation.valid?

      ApplicationRecord.transaction do
        # Debit inside the transaction so an insufficient balance blocks the
        # create and a failed save never burns a credit.
        user.spend_credit!(reason: "invitation_created", event_kind: "invitation_created")

        # Handle cover image
        if cover_image_file.present? && cover_image_file.respond_to?(:to_io)
          invitation.cover_image.attach(io: cover_image_file.to_io, filename: cover_image_file.original_filename)
        elsif cover_image_url.present?
          # Handle URL-based cover images (from gallery selection)
          downloaded_file = URI.open(cover_image_url)
          uri = URI.parse(cover_image_url)
          filename = File.basename(T.must(uri.path))
          invitation.cover_image.attach(io: downloaded_file, filename: filename)
        end

        invitation.save!

        { invitation: invitation, errors: [] }
      end
    rescue User::InsufficientCreditsError
      { invitation: nil, errors: [ INSUFFICIENT_CREDITS_ERROR ] }
    rescue ActiveRecord::RecordInvalid => e
      { invitation: nil, errors: e.record.errors.full_messages }
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
