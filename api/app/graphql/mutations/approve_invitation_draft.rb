# typed: true
# frozen_string_literal: true

module Mutations
  class ApproveInvitationDraft < BaseMutation
    # Accept a transient draft payload (ai_payload or preview fields) and create an Invitation
    argument :preview_title, String, required: false
    argument :preview_message, String, required: false
    argument :preview_event_date, GraphQL::Types::ISO8601Date, required: false
    argument :preview_event_time, String, required: false
    argument :preview_location, String, required: false
    argument :ai_payload, GraphQL::Types::JSON, required: false

    field :invitation, Types::InvitationType, null: true
    field :errors, [ String ], null: false

    def resolve(preview_title: nil, preview_message: nil, preview_event_date: nil, preview_event_time: nil, preview_location: nil, ai_payload: nil)
      user = context[:current_user]
      return { invitation: nil, errors: [ "You must be signed in" ] } unless user

      # Prefer explicit previews if provided, otherwise extract from ai_payload
      # T.unsafe: ai_payload is JSON that could have string or symbol keys
      unsafe_payload = T.unsafe(ai_payload)
      title = preview_title || ai_payload&.dig("content", "title") || unsafe_payload&.dig(:content, :title)
      message = preview_message || ai_payload&.dig("content", "message") || unsafe_payload&.dig(:content, :message)
      event_date = preview_event_date || ai_payload&.dig("content", "event_date") || unsafe_payload&.dig(:content, :event_date)
      event_time = preview_event_time || ai_payload&.dig("content", "event_time") || unsafe_payload&.dig(:content, :event_time)
      location = preview_location || ai_payload&.dig("content", "location") || unsafe_payload&.dig(:content, :location)

      # Minimal validation
      return { invitation: nil, errors: [ "Title is required" ] } if title.blank?
      return { invitation: nil, errors: [ "Event date is required" ] } if event_date.blank?
      return { invitation: nil, errors: [ "Event time is required" ] } if event_time.blank?

      # Normalize event_time
      formatted_time = format_time(event_time)
      return { invitation: nil, errors: [ "Event time must be parseable" ] } unless formatted_time

      invitation = user.invitations.build(
        title: title,
        description: message,
        location: location,
        event_date: event_date,
        event_time: formatted_time,
        external_id: SecureRandom.uuid
      )

      ApplicationRecord.transaction do
        # Persisting the invitation costs a credit; debit inside the
        # transaction so an insufficient balance blocks the create and a failed
        # save never burns a credit.
        user.spend_credit!(reason: "invitation_created", event_kind: "invitation_created")

        invitation.save!

        { invitation: invitation, errors: [] }
      end
    rescue User::InsufficientCreditsError
      { invitation: nil, errors: [ INSUFFICIENT_CREDITS_ERROR ] }
    rescue ActiveRecord::RecordInvalid => e
      { invitation: nil, errors: e.record.errors.full_messages }
    rescue StandardError => e
      { invitation: nil, errors: [ e.message ] }
    end

    private

    def format_time(time_string)
      return nil if time_string.blank?
      time = Time.parse(time_string)
      time.strftime("%H:%M")
    rescue ArgumentError
      nil
    end
  end
end
