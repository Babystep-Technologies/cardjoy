# typed: true
# frozen_string_literal: true

# Renders a holiday card through PostGrid and stores the resulting PDF as the
# proof the user approves before we print (issue #144).
#
#   HolidayCard::ProofGenerator.new(card).generate! # => card, with proof_* set
#
# ## Why PostGrid renders the proof
#
# Our React editor draws the card with a browser; PostGrid prints it with their
# renderer. Those two will not agree perfectly — font rasterization, sub-pixel
# rounding, how an oversized image inside an `overflow: hidden` box gets
# clipped. A 2% difference nobody notices on screen is a face cropped at the
# hairline on forty printed cards, and there is no undo once an order is
# `printing`.
#
# So the proof is not our render of the card. It is *PostGrid's* render, from
# the exact HTML the real order will carry, produced by the exact renderer that
# will print it. What the user approves is what gets printed.
#
# ## Why the test key, always
#
# Creating a postcard with `test_sk_…` returns a real PDF at `url`, mails
# nothing, and costs nothing. That is what makes this affordable to run before
# taking anyone's money. `MODE` is hard-coded rather than read from
# `PostGrid.default_mode`: a proof must never be a live order, and that must not
# depend on how `POSTGRID_MODE` happens to be set on the box.
#
# ## What it does not do
#
# It does not approve anything — generation and approval are two mutations
# because they are two decisions, and the user makes the second one after
# looking at the PDF. It also writes nothing on failure, so a PostGrid outage
# leaves the previous proof intact rather than blanking the one good render the
# user had.
class HolidayCard::ProofGenerator
  extend T::Sig

  POSTCARDS_PATH = "/postcards"

  # Never `PostGrid.default_mode`. See the class note.
  MODE = :test

  # PostGrid will not create a postcard without both addresses, and this card
  # has neither: a holiday card has no return address of its own yet, and a
  # proof by definition has no recipient — it is rendered before the user has
  # picked one.
  #
  # These are the USPS-reserved example addresses, chosen so that anyone reading
  # a proof PDF or a PostGrid dashboard row can tell at a glance that no real
  # person is involved. The address block is PostGrid's own region on the back
  # panel (`HolidayCardCatalogue::RESERVED_ADDRESS_BLOCKS`), so what these change
  # in the proof is only the text inside a block the user's design never touches.
  #
  # TODO(#148): the send flow renders per recipient and has a real `to`. When a
  # return address lands on the card, `from` here should follow it so the proof
  # shows the sender the user will actually print.
  PLACEHOLDER_ADDRESS = {
    addressLine1: "1600 Pennsylvania Ave NW",
    city: "Washington",
    provinceOrState: "DC",
    postalOrZip: "20500",
    countryCode: "US"
  }.freeze

  PLACEHOLDER_RECIPIENT_NAME = "Proof Recipient"

  sig { params(card: ::HolidayCard, client: T.nilable(PostGrid::Client)).void }
  def initialize(card, client: nil)
    @card = card
    @client = client || PostGrid::Client.new(mode: MODE)
  end

  # Renders, submits, and stores. Returns the card with its `proof_*` columns
  # set.
  #
  # Raises rather than returning errors: `PostGrid::Error` subclasses and
  # `PrintRenderer::UnknownTemplateError` both mean something the *mutation*
  # has to turn into a user-facing sentence, and swallowing them here would
  # leave the caller unable to tell "no proof" from "proof unchanged".
  sig { returns(::HolidayCard) }
  def generate!
    panels = ::HolidayCard::PrintRenderer.new(card).render

    # Captured before the call, not after: it is the digest of what we are
    # *sending*, and a concurrent edit landing mid-request must not be able to
    # claim this render depicts it.
    digest = card.proof_design_digest_for_current_design

    payload = @client.create(POSTCARDS_PATH, body: body_for(panels), idempotency_key: SecureRandom.uuid)

    store!(payload, digest)
  end

  private

  attr_reader :card

  def body_for(panels)
    {
      to: PLACEHOLDER_ADDRESS.merge(firstName: PLACEHOLDER_RECIPIENT_NAME),
      from: PLACEHOLDER_ADDRESS.merge(firstName: card.user.name.presence || "CardJoy"),
      frontHTML: panels.fetch(:front),
      backHTML: panels.fetch(:back),
      # Passed through from `HolidayCard::VALID_SIZES`, which is also what the
      # renderer sized the HTML to. If PostGrid ever rejects one of our size
      # strings it comes back as an InvalidRequestError and reaches the user as
      # a sentence — the size the proof renders at is exactly the thing this
      # whole mechanism exists to catch before anything is printed.
      size: card.size,
      # Test-mode orders do show up on the PostGrid dashboard, so it is worth
      # their being self-explanatory to whoever is debugging a print later.
      description: "CardJoy proof #{card.external_id}"
    }
  end

  # `url` is the whole point of the call, so its absence is a failed proof even
  # though PostGrid answered 2xx — better to raise here than to store a nil URL
  # that `proof_current?` would then have to treat as a special case.
  def store!(payload, digest)
    url = payload["url"].presence
    raise PostGrid::ServiceError, "PostGrid returned no proof URL" unless url

    card.update!(
      proof_url: url,
      proof_generated_at: Time.current,
      proof_design_digest: digest,
      # A new render is a new thing to look at. Carrying an approval across it
      # would let a user approve one PDF and print another.
      proof_approved_at: nil
    )
    card
  end
end
