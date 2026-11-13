# typed: true
# frozen_string_literal: true

# Daily cron job (config/initializers/good_job.rb), #248. A claim is a promise, and promises lapse:
# a guest who claimed something and never bought it leaves the owner thinking it is covered. So an
# unpurchased claim gets a reminder after WishListReservation::REMIND_AFTER and is released
# RELEASE_AFTER_REMINDER later. A claim the guest marked as purchased is never touched.
#
# Idempotent: `reminded_at` is stamped as the reminder is enqueued, and a released claim is gone,
# so a re-run neither double-reminds nor double-releases.
class StaleWishListClaimsJob < ApplicationJob
  queue_as :default

  def perform
    # Release first: a claim reminded long ago must not be reminded again by the same run.
    WishListReservation.due_for_release.find_each do |reservation|
      release(reservation)
    rescue StandardError => e
      Rails.logger.error "StaleWishListClaimsJob: failed to release #{reservation.id}: #{e.message}"
    end

    WishListReservation.due_for_reminder.find_each do |reservation|
      remind(reservation)
    rescue StandardError => e
      Rails.logger.error "StaleWishListClaimsJob: failed to remind #{reservation.id}: #{e.message}"
    end
  end

  private

  def release(reservation)
    # Capture what the email needs before the row is gone.
    WishListMailer.claim_released(
      guest_name: reservation.guest_name,
      guest_email: reservation.guest_email,
      item_title: reservation.wish_list_item.title,
      wish_list: reservation.wish_list_item.wish_list
    ).deliver_later
    reservation.destroy!
  end

  def remind(reservation)
    WishListMailer.claim_reminder(reservation).deliver_later
    reservation.update!(reminded_at: Time.current)
  end
end
