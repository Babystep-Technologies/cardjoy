# typed: true
# frozen_string_literal: true

module Mutations
  # Emails a reminder to the guests who RSVPed to an invitation (#319). Only people who answered
  # are written to: those are the only addresses the host has, and each gave theirs for this event.
  #
  # Limited to one send per invitation per day (Invitation::REMINDER_INTERVAL) and refused once the
  # event is over.
  class SendInvitationReminder < BaseMutation
    argument :external_id, String, required: true
    argument :audience, String, required: false, default_value: "going_and_maybe",
      description: "going, maybe, or going_and_maybe."
    argument :note, String, required: false, description: "A personal line shown above the event details."

    field :sent_count, Integer, null: false
    field :invitation, Types::InvitationType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:, audience:, note: nil)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      invitation = ::Invitation.find_by(external_id: external_id)
      return failure("Invitation not found") unless invitation&.editable_by?(user)
      return failure("This invitation is locked") if invitation.locked
      return failure("The event has already happened") if invitation.past?

      statuses = ::Invitation::REMINDER_AUDIENCES[audience]
      return failure("Choose who to remind") unless statuses

      note = note.to_s.strip.presence
      if note && note.length > ::Invitation::REMINDER_NOTE_MAX_LENGTH
        return failure("Keep the note under #{::Invitation::REMINDER_NOTE_MAX_LENGTH} characters")
      end

      rsvps = invitation.rsvps.where(status: statuses).to_a
      return failure("No one has RSVPed #{audience_label(audience)} yet") if rsvps.empty?

      # Claimed in one UPDATE so two quick clicks can't both pass the daily limit.
      return failure(too_soon_message(invitation)) unless claim_send(invitation)

      rsvps.each { |rsvp| RsvpMailer.event_reminder(rsvp, note).deliver_later }

      { sent_count: rsvps.size, invitation: invitation.reload, errors: [] }
    end

    private

    def claim_send(invitation)
      ::Invitation.where(id: invitation.id)
        .where("reminder_sent_at IS NULL OR reminder_sent_at < ?", ::Invitation::REMINDER_INTERVAL.ago)
        .update_all(reminder_sent_at: Time.current) == 1
    end

    def too_soon_message(invitation)
      next_at = invitation.reload.next_reminder_at
      return "A reminder was just sent" unless next_at

      "A reminder was already sent today. You can send another after #{next_at.utc.strftime('%-I:%M %p UTC')}"
    end

    def audience_label(audience)
      { "going" => "going", "maybe" => "maybe" }.fetch(audience, "going or maybe")
    end

    def failure(*messages)
      { sent_count: 0, invitation: nil, errors: messages }
    end
  end
end
