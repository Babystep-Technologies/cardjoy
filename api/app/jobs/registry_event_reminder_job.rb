# typed: true
# frozen_string_literal: true

# Daily cron job (config/initializers/good_job.rb), #251. Emails a registry's owner once, within
# WishList::EVENT_REMINDER_LEAD of the event, to get it in front of people. Owners can opt out per
# registry, and a registry whose event has passed is never reminded.
#
# Idempotent: `event_reminded_at` is stamped as the email is enqueued.
class RegistryEventReminderJob < ApplicationJob
  queue_as :default

  def perform
    WishList.due_for_event_reminder.includes(:user).find_each do |wish_list|
      WishListMailer.event_reminder(wish_list).deliver_later
      wish_list.update_columns(event_reminded_at: Time.current)
    rescue StandardError => e
      Rails.logger.error "RegistryEventReminderJob: failed to remind #{wish_list.id}: #{e.message}"
    end
  end
end
