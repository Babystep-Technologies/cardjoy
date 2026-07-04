# typed: true
# frozen_string_literal: true

class NotifyRsvpsOfUpdateJob < ApplicationJob
  queue_as :default

  def perform(invitation_id)
    invitation = Invitation.find_by(id: invitation_id)
    return unless invitation

    # Find all RSVPs who are going or maybe
    rsvps_to_notify = invitation.rsvps.where(status: [ "going", "maybe" ])

    Rails.logger.info "NotifyRsvpsOfUpdateJob: Sending update notifications to #{rsvps_to_notify.count} RSVPs for invitation #{invitation_id}"

    rsvps_to_notify.each do |rsvp|
      begin
        RsvpMailer.invitation_updated(rsvp).deliver_later
        Rails.logger.info "NotifyRsvpsOfUpdateJob: Queued update notification for #{rsvp.guest_email}"
      rescue StandardError => e
        Rails.logger.error "NotifyRsvpsOfUpdateJob: Failed to send update notification to #{rsvp.guest_email}: #{e.message}"
      end
    end

    Rails.logger.info "NotifyRsvpsOfUpdateJob: Completed notification job for invitation #{invitation_id}"
  end
end
