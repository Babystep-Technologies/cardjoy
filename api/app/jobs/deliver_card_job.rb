# typed: true
# frozen_string_literal: true

# Delivers a scheduled 1-on-1 card email when its `deliver_at` time arrives.
# Enqueued by the `deliverCard` mutation with `wait_until: card.deliver_at`.
#
# The `scheduled_for` argument records the `deliver_at` the job was enqueued
# for. If the card was cancelled (`deliver_at` cleared) or rescheduled
# (`deliver_at` changed, which enqueues a fresh job) before this job runs, the
# guards below make it a no-op so the card is not delivered at the stale time.
class DeliverCardJob < ApplicationJob
  queue_as :default

  def perform(card_external_id, recipient_email, scheduled_for)
    card = Card.find_by(external_id: card_external_id)
    return unless card

    # Cancelled: the scheduled send was called off.
    deliver_at = card.deliver_at
    return if deliver_at.blank?

    # Rescheduled: a different job now owns the current delivery time.
    return unless deliver_at.iso8601 == scheduled_for

    CardMailer.one_on_one_delivery(recipient_email, card).deliver_later
  end
end
