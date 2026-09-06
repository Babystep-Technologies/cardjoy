# typed: true
# frozen_string_literal: true

# Submits one already-charged mail order to PostGrid (issue #148). One order per
# job, enqueued after the send mutation's transaction has committed.
#
# ## Why the external call is out here
#
# `Mutations::SendHolidayCard` re-prices, debits, and writes the order rows
# inside one transaction, and deliberately submits nothing. An HTTP call inside
# a transaction holds a database connection open for a network round trip and —
# far worse — cannot be rolled back: a `ROLLBACK` after PostGrid accepted the
# postcard un-charges the user for a card that is already printing.
#
# ## The three outcomes
#
# * **Success** — `postgrid_id` and `submitted_at` recorded, status `submitted`.
# * **Retryable** (`ServiceError`, `RateLimitError`) — PostGrid is unwell or
#   throttling us. The order stays `pending`, the wallet is untouched, and the
#   job comes back with backoff. Replaying is safe because the order's
#   `idempotency_key` is stable across attempts, so PostGrid returns the
#   original postcard rather than printing a second one.
# * **Terminal** (`InvalidRequestError`, a retired template, or retries
#   exhausted) — the order is marked `failed` with a reason and **refunded**. A
#   4xx will not fix itself, and the user must not be left paying for a card
#   nobody will ever receive.
#
# `AuthenticationError` is terminal-and-refunded too, even though it is our
# fault rather than the order's: retrying a bad key just fails again, and
# holding the user's money against a config error we might not notice for a day
# is not a defensible default. The refund is reversible — a re-send is one
# mutation — and the log line says what actually happened.
class HolidayCardMailSubmissionJob < ApplicationJob
  queue_as :default

  # A card the user paid for is worth more patience than a proof render. Roughly
  # ten minutes of PostGrid being unavailable before we give up and refund.
  MAX_ATTEMPTS = 6

  # What a user reads on a failed order, per error class. PostGrid's own message
  # is passed through only for `InvalidRequestError`, where it describes
  # something about *this* piece ("address is undeliverable") and is written for
  # a human. Every other class produces an internal message about our
  # infrastructure, which is not the user's business and may name our key.
  UNAVAILABLE_REASON = "We couldn't reach our print partner, so this card wasn't sent. " \
                       "You haven't been charged — please try again."
  TEMPLATE_RETIRED_REASON = "This card's template is no longer available, so it couldn't be printed. " \
                            "You haven't been charged."

  retry_on PostGrid::ServiceError, PostGrid::RateLimitError,
    wait: :polynomially_longer, attempts: MAX_ATTEMPTS do |job, error|
    # Retries exhausted. Same terminal path as a 4xx: PostGrid has been
    # unreachable for long enough that "it might work next time" has stopped
    # being true, and the money goes back.
    job.fail_and_refund(job.arguments.first, UNAVAILABLE_REASON, error)
  end

  # `order_id` rather than a GlobalID'd record so a deleted order deserializes
  # to nil and is skipped, instead of raising DeserializationError on every
  # attempt.
  def perform(order_id)
    order = HolidayCardMailOrder.find_by(id: order_id)
    return unless order

    # Not a race guard — that lives in the conditional UPDATE inside
    # `fail_and_refund!` and in MailSubmission's own `pending?` check. This is
    # here so a re-run of an order that already succeeded is a no-op with no
    # HTTP call at all.
    return unless order.pending?

    HolidayCard::MailSubmission.new(order).submit!
    Rails.logger.info("[HolidayCardMailSubmissionJob] order=#{order.id} submitted postgrid_id=#{order.reload.postgrid_id}")
  rescue ::HolidayCard::PrintRenderer::UnknownTemplateError => e
    fail_and_refund(order_id, TEMPLATE_RETIRED_REASON, e)
  rescue PostGrid::InvalidRequestError => e
    # The only place PostGrid's wording reaches a user. It is about this piece.
    fail_and_refund(order_id, "Our print partner couldn't accept this card: #{e.message}", e)
  rescue PostGrid::AuthenticationError, PostGrid::ConfigurationError => e
    fail_and_refund(order_id, UNAVAILABLE_REASON, e)
  end

  # Public because the `retry_on` exhaustion block above receives the job
  # instance and has to reach it; not part of the job's interface otherwise.
  #
  # Idempotent by way of `HolidayCardMailOrder#fail_and_refund!`, which claims
  # the order with a conditional UPDATE and only refunds if it won. A second run
  # logs and moves on.
  def fail_and_refund(order_id, reason, error)
    order = HolidayCardMailOrder.find_by(id: order_id)
    return unless order

    refunded = order.fail_and_refund!(reason:)
    # The error class, never its message: a PostGrid message can quote an
    # address back at us, and this application's logs are not a place one
    # belongs (see PostGrid::Client's logging note).
    Rails.logger.warn(
      "[HolidayCardMailSubmissionJob] order=#{order.id} failed error=#{error.class} refunded=#{refunded}"
    )
  end
end
