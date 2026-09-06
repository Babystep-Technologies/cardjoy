# typed: true
# frozen_string_literal: true

# Hands one already-charged mail order to PostGrid (issue #148).
#
#   HolidayCard::MailSubmission.new(order).submit! # => order, submitted
#
# ## Why the live key, always
#
# `ProofGenerator::MODE` is hard-coded to `:test`; this is the other pole of the
# same decision, and for a sharper reason. A test-mode create returns 2xx,
# returns an id, and mails nothing. If a box with `POSTGRID_MODE=test` ran real
# sends, every order would look successful, the wallet would be debited, and
# nothing would arrive — the one failure mode with no signal anywhere. So the
# mode is a property of what this class *is*, not of how a box is configured,
# and a deploy with no live key can't send at all (see
# `Mutations::SendHolidayCard`, which refuses up front).
#
# ## Why it does not decide anything
#
# It renders, posts, and records success. Every PostGrid error propagates, and
# `HolidayCardMailSubmissionJob` decides which are worth retrying and which are
# terminal-and-refundable. Those are two different jobs: this one knows how to
# talk to PostGrid, that one knows what a failure costs the user.
#
# It is also a no-op on an order that isn't `pending`, so a duplicate job run
# makes no second HTTP call. The `Idempotency-Key` is the backstop underneath
# that, for the case the two runs genuinely race.
class HolidayCard::MailSubmission
  extend T::Sig

  POSTCARDS_PATH = "/postcards"

  # Never `PostGrid.default_mode`. See the class note.
  MODE = :live

  # PostGrid requires a return address on every piece, and a holiday card
  # carries no sender address of its own yet — the same gap
  # `ProofGenerator::PLACEHOLDER_ADDRESS` documents. Reusing that constant keeps
  # the proof the user approved and the piece we print addressed identically,
  # which is the whole point of the proof. When a real return address lands on
  # the card, both should follow it together.
  RETURN_ADDRESS = ::HolidayCard::ProofGenerator::PLACEHOLDER_ADDRESS

  sig { params(order: ::HolidayCardMailOrder, client: T.nilable(PostGrid::Client)).void }
  def initialize(order, client: nil)
    @order = order
    @client = client || PostGrid::Client.new(mode: MODE)
  end

  # Submits and records. Returns false without calling PostGrid when the order
  # has already left `pending`.
  sig { returns(T::Boolean) }
  def submit!
    return false unless order.pending?

    panels = ::HolidayCard::PrintRenderer.new(order.holiday_card).render
    payload = @client.create(POSTCARDS_PATH, body: body_for(panels), idempotency_key: order.idempotency_key)

    store!(payload)
  end

  private

  attr_reader :order

  def body_for(panels)
    {
      to: recipient_address,
      from: RETURN_ADDRESS.merge(firstName: order.user.name.presence || "CardJoy"),
      frontHTML: panels.fetch(:front),
      backHTML: panels.fetch(:back),
      size: order.size,
      # Our own id, so a PostGrid dashboard row can be traced back to an order
      # without a lookup table. The recipient's name is deliberately absent —
      # the description is metadata, and metadata is not where an address goes.
      description: "CardJoy holiday card #{order.holiday_card.external_id} order #{order.id}"
    }
  end

  # Built from `recipient_snapshot`, never from `order.contact`. The contact may
  # have been edited or deleted since the charge, and what we mail has to be
  # what was priced and what the user was shown.
  def recipient_address
    snapshot = order.recipient_snapshot
    {
      firstName: snapshot["name"],
      addressLine1: snapshot["address_line1"],
      addressLine2: snapshot["address_line2"],
      city: snapshot["city"],
      provinceOrState: snapshot["region"],
      postalOrZip: snapshot["postal_code"],
      countryCode: snapshot["country_code"]
    }.compact_blank
  end

  # An id is the one thing we cannot do without: it is how this piece is traced,
  # cancelled, or reconciled later. A 2xx that carries none is treated as a
  # service failure so the job retries under the same idempotency key, rather
  # than being recorded as a success we can never look up.
  def store!(payload)
    postgrid_id = (payload["id"] || payload.dig("data", "id")).presence
    raise PostGrid::ServiceError, "PostGrid returned no postcard id" unless postgrid_id

    order.mark_submitted!(postgrid_id:, postgrid_status: payload["status"])
  end
end
