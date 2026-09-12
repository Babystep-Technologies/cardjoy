# typed: true
# frozen_string_literal: true

# Turns a customer's emailed reply into a `customer` SupportTicketMessage
# (#174). ApplicationMailbox routes anything addressed to `support+...` here;
# the token after the `+` is minted by SupportTicket#reply_to_address and
# resolved back to a ticket by SupportTicket.active_for_reply_token.
#
# Three paths end without a message ever being created, on purpose:
#
# * An unknown or revoked token bounces — see #bounced! below — rather than
#   silently dropping mail or, worse, guessing a ticket.
# * An auto-responder (vacation reply, NDR) is dropped with no bounce at all.
#   Bouncing one is itself a reply, and replying to an autoresponder is
#   exactly how two mail servers loop forever.
# * A ticket already at the rate limit is dropped with no bounce either, for
#   the same loop-prevention reason — the flood is far more likely to be a
#   broken auto-responder than a customer typing fast.
class SupportTicketMailbox < ApplicationMailbox
  # Far more than any real customer thread produces in an hour; only a loop
  # gets anywhere near this.
  RATE_LIMIT_MAX_MESSAGES = 20
  RATE_LIMIT_PERIOD = 1.hour

  # Long enough for any real reply. A longer body is either an inlined
  # forward/attachment dump or abuse, neither of which belongs verbatim in the
  # ticket thread.
  MAX_BODY_LENGTH = 20_000

  def process
    return if auto_responder?
    return bounced! unless ticket
    return if rate_limited?

    ticket.record_customer_reply!(user: ticket.user, body: extracted_body, inbound_email_id: inbound_email.id.to_s)
  end

  private

  def ticket
    @ticket ||= T.let(SupportTicket.active_for_reply_token(reply_token), T.nilable(SupportTicket))
  end

  def reply_token
    address = mail.recipients.find { |recipient| recipient.to_s.match?(/\Asupport\+/i) }
    address&.[](/\Asupport\+([^@]+)@/i, 1)
  end

  # RFC 3834's `Auto-Submitted` header, plus the vendor-specific headers real
  # vacation responders and mailing-list software still send instead of (or as
  # well as) it.
  def auto_responder?
    auto_submitted = mail["Auto-Submitted"]&.value.to_s.downcase
    return true if auto_submitted.present? && auto_submitted != "no"

    %w[X-Autoreply X-Autorespond].any? { |header| mail[header].present? }
  end

  def rate_limited?
    recent_replies = T.must(ticket).messages
      .where(author_kind: SupportTicketMessage::CUSTOMER)
      .where("created_at >= ?", RATE_LIMIT_PERIOD.ago)
      .count

    return false if recent_replies < RATE_LIMIT_MAX_MESSAGES

    Rails.logger.warn("[SupportTicketMailbox] rate limited ticket=#{T.must(ticket).external_id}")
    true
  end

  def extracted_body
    InboundEmailReplyExtractor.call(plain_text_body).truncate(MAX_BODY_LENGTH, omission: "… (truncated)")
  end

  # Prefers the text part; an HTML-only email falls back to its tags stripped
  # rather than dumping raw markup into the ticket thread.
  def plain_text_body
    return mail.decoded.to_s unless mail.multipart?

    mail.text_part&.decoded || Rails::Html::FullSanitizer.new.sanitize(mail.html_part&.decoded.to_s)
  end
end
