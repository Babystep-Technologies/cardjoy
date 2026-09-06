# typed: true
# frozen_string_literal: true

# Where PostGrid tells us what happened to a card we mailed (issue #149).
#
# Once an order is submitted PostGrid owns it: it moves `ready` → `printing` →
# `processed_for_delivery` → `completed`, picks up a tracking number somewhere
# along the way, and can be cancelled. Polling every open order would be slow
# and rude, so this endpoint is how any of that reaches us.
#
# Modelled on StripeWebhooksController, with the same three instincts:
#
# * **Verify the signature.** This endpoint mutates order state and issues
#   refunds. "The URL is unguessable" is not an access control, and an
#   unverified caller could cancel-and-refund every order whose PostGrid id
#   they can guess. No secret configured means every request is rejected.
# * **Answer quickly.** PostGrid redelivers anything it doesn't get a prompt
#   2xx for, so the actual work goes to PostgridWebhookJob and this renders.
# * **2xx almost everything.** An event about an id we don't know, a type we
#   don't handle, or a body we can't parse is a no-op, not a 500 — a 5xx here
#   buys an unbounded redelivery of something we will never act on. 401 is the
#   one exception, and the only thing this refuses.
class PostgridWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  # `t=<unix seconds>,v1=<hex hmac-sha256 of "<t>.<raw body>">`, the same scheme
  # Stripe uses. Rails maps this to HTTP_POSTGRID_SIGNATURE for us.
  SIGNATURE_HEADER = "PostGrid-Signature"

  # PostGrid fires `<kind>.updated` for letters, postcards, cheques, and
  # self mailers on one endpoint. We only send postcards today; anything else
  # belongs to a product we don't have and is logged rather than assumed.
  POSTCARD_UPDATED = "postcard.updated"

  def create
    payload = request.raw_post

    unless valid_signature?(payload)
      Rails.logger.warn("[PostgridWebhook] rejected: signature did not verify")
      return render json: { error: "Unauthorized" }, status: :unauthorized
    end

    enqueue(parse(payload))
    render json: { received: true }
  end

  private

  # Constant-time over the whole header value, and false rather than an
  # exception on anything malformed — a caller must not be able to tell a
  # missing secret from a wrong signature from a header we couldn't parse.
  def valid_signature?(payload)
    secret = PostGrid.webhook_secret
    return false if secret.blank?

    parts = request.headers[SIGNATURE_HEADER].to_s.split(",").filter_map do |part|
      key, value = part.strip.split("=", 2)
      [ key, value ] if key.present? && value.present?
    end.to_h

    timestamp = parts["t"]
    provided = parts["v1"]
    return false if timestamp.blank? || provided.blank?

    expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  end

  def parse(payload)
    JSON.parse(payload)
  rescue JSON::ParserError
    Rails.logger.warn("[PostgridWebhook] ignored: body did not parse as JSON")
    {}
  end

  # Everything past the signature check is shaped like PostGrid's payload:
  # `type` names the event, `data` is the order object it happened to.
  def enqueue(event)
    type = event["type"].to_s
    data = event["data"]
    postgrid_id = data.is_a?(Hash) ? data["id"].presence : nil

    if type != POSTCARD_UPDATED
      Rails.logger.info("[PostgridWebhook] ignored type=#{type.inspect}")
      return
    end

    # A postcard event with no id names nothing we could look up.
    unless postgrid_id
      Rails.logger.warn("[PostgridWebhook] ignored #{POSTCARD_UPDATED} with no id")
      return
    end

    PostgridWebhookJob.perform_later(
      postgrid_id: postgrid_id.to_s,
      postgrid_status: data["status"].presence&.to_s,
      tracking_number: data["trackingNumber"].presence&.to_s
    )
  end
end
