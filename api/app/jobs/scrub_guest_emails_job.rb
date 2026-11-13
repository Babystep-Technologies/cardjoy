# typed: true
# frozen_string_literal: true

# Daily cron job (config/initializers/good_job.rb), #252. A guest hands over an email address to
# claim a gift, so it is kept only as long as it is useful: a week past the event, for thank-you
# notes. Then it is erased. The claim and the guest's name stay, so the owner can still see who gave
# what. Idempotent: a scrubbed row no longer matches.
class ScrubGuestEmailsJob < ApplicationJob
  queue_as :default

  def perform
    scrubbed = WishListReservation
      .where(wish_list_item_id: WishListItem.where(wish_list_id: WishList.due_for_email_scrub.select(:id)).select(:id))
      .where.not(guest_email: nil)
      .update_all(guest_email: nil, updated_at: Time.current)
    Rails.logger.info "ScrubGuestEmailsJob: erased #{scrubbed} guest email(s)"
  end
end
