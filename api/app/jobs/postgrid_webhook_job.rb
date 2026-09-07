# typed: true
# frozen_string_literal: true

# Applies one verified PostGrid `postcard.updated` event to the order it names
# (issue #149).
#
# ## Why this isn't done in the controller
#
# PostGrid retries a delivery it doesn't get a prompt 2xx for, so a handler that
# does its work inline turns one slow request into a queue of duplicates of
# itself. `PostgridWebhooksController` verifies the signature, pulls out the
# three fields that matter, and hands them here; the socket closes while the
# transition is still queued.
#
# ## Why primitives rather than the event
#
# The controller has already decided this is a postcard event and extracted the
# id, status, and tracking number. Serializing the whole PostGrid object into
# the queue would carry a recipient's address through the job backend for no
# gain — the order already holds the address it was mailed to.
#
# Everything that can go wrong here is a no-op by design: an unknown id, a
# status we don't map, a replay, and an event that arrives late are all handled
# by logging and moving on. Nothing raises, because a raise means PostGrid keeps
# redelivering an event we will never be able to act on.
class PostgridWebhookJob < ApplicationJob
  queue_as :default

  def perform(postgrid_id:, postgrid_status: nil, tracking_number: nil)
    order = HolidayCardMailOrder.find_by(postgrid_id: postgrid_id)

    # Not an error. Proofs are created through the same account, as are the
    # orders of every other environment sharing it, and PostGrid reports on all
    # of them. Raising would earn us an infinite redelivery of an event about
    # something that isn't ours.
    unless order
      Rails.logger.info(
        "[PostgridWebhook] unrecognized postgrid_id=#{postgrid_id} postgrid_status=#{postgrid_status}"
      )
      return
    end

    before = order.status
    outcome = order.apply_postgrid_update!(postgrid_status:, tracking_number:)

    # The only record of what the outside world told us about a physical
    # mailing, so it says both what arrived and what we did about it. The
    # tracking number is deliberately absent: it is a fact about a named
    # person's parcel, and it is on the order for anyone who needs it.
    Rails.logger.info(
      "[PostgridWebhook] order=#{order.id} postgrid_id=#{postgrid_id} " \
      "postgrid_status=#{postgrid_status} #{before}->#{order.reload.status} outcome=#{outcome}"
    )
  end
end
