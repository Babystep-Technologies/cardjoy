# typed: true
# frozen_string_literal: true

# Daily cron job (see config/initializers/good_job.rb) that drives CardJoy's
# proactive retention loop (issue #28): it finds occasion-book occasions whose
# next occurrence is within the reminder lead window and emails each contact's
# owner a reminder with a curated design suggestion and a deep link into the
# pre-filled create flow.
#
# Idempotent: each occasion is stamped with `last_reminded_at` as soon as its
# reminder is enqueued, and `Occasion.due_for_reminder` excludes anything
# already reminded for the current occurrence — so re-runs never double-send.
class OccasionReminderJob < ApplicationJob
  queue_as :default

  def perform
    due = Occasion.due_for_reminder
    Rails.logger.info "OccasionReminderJob: #{due.size} occasion(s) due for a reminder"

    due.each do |occasion|
      OccasionReminderMailer.upcoming_occasion(occasion).deliver_later
      occasion.record_reminder!
      Rails.logger.info "OccasionReminderJob: reminded occasion #{occasion.id} (#{occasion.kind}) for contact #{occasion.contact_id}"
    rescue StandardError => e
      Rails.logger.error "OccasionReminderJob: failed to remind occasion #{occasion.id}: #{e.message}"
    end
  end
end
