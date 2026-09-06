# typed: true
# frozen_string_literal: true

# What one piece of physical mail costs the user, in US cents (issue #147).
#
#   MailPricing.quote(size: "6x4", zone: "us_domestic") # => #<Quote total_cents=112 …>
#
# ## Why this is a constant and not a call to PostGrid
#
# PostGrid has no price-quote endpoint. `POST /print-mail/v1/postcards` returns
# an id, a status, and a rendered PDF — no cost field, and there is no `/quote`
# to ask beforehand. What we pay is a rate card negotiated with them: size ×
# mailing class × destination zone.
#
# So "use PostGrid to assess the shipping cost" resolves into two halves.
# PostGrid::AddressVerification is the authority on *where* an address is (it
# hands back the zone); this file is the authority on what that costs. Neither
# one can answer the other's question.
#
# ## Why the rate card is versioned
#
# PostGrid's rates move, and orders outlive them. A card mailed in December has
# to still be explainable in March — "why was I charged 112¢?" is a support
# question with a right answer, and the answer is the rate card that was in
# force when the charge happened. So every version we have ever billed under
# stays in `RATE_CARDS`, and the order records the version it used alongside the
# resolved cents. Old entries are history, not dead code; deleting one makes a
# past charge unreconstructable.
#
# ## Why an unknown zone raises
#
# The tempting alternative — fall back to the domestic rate — means mailing to
# Australia at the US price and quietly eating the difference on every piece.
# A missing rate is not an edge case, it is us not knowing what something costs,
# and the only correct response is to refuse to sell it. Callers turn
# `UnknownRateError` into "we can't mail to this destination yet".
class MailPricing
  extend T::Sig

  # Raised when the rate card has no entry for a (size, mailing class, zone).
  # Never rescued into a default price — see the class note.
  class UnknownRateError < StandardError; end

  # Raised for a rate card version we have never shipped. Distinct from
  # UnknownRateError because it means a bad argument, not an unmailable
  # destination, and no user-facing sentence would make sense.
  class UnknownRateCardError < StandardError; end

  # The version new quotes price under. Bumping this is the whole deploy story
  # for a rate change: add a version to RATE_CARDS, point this at it, leave the
  # old one in place.
  CURRENT_RATE_CARD_VERSION = "2026-01"

  # PostGrid's mailing classes for postcards. Only one today; it is an explicit
  # dimension of the rate card rather than an assumption baked into the keys,
  # because standard/marketing class is the obvious next thing to offer and it
  # prices differently.
  MAILING_CLASS_FIRST_CLASS = "first_class"
  MAILING_CLASSES = [ MAILING_CLASS_FIRST_CLASS ].freeze
  DEFAULT_MAILING_CLASS = MAILING_CLASS_FIRST_CLASS

  # Our cost, in US cents, per piece: [size, mailing class, zone] => cents.
  #
  # Sized from PostGrid's published print-and-mail list rates (86¢ for 6x4 and
  # 98¢ for 6x9 domestic, higher for Canada and international). These are list
  # prices; they should be replaced with our contracted numbers as a new version
  # rather than an edit, so anything already billed stays reconstructable.
  #
  # Zones are PostGrid::AddressVerification's three, and adding a finer one
  # later is a change to this constant and nothing else.
  RATE_CARDS = {
    "2026-01" => {
      [ "6x4", MAILING_CLASS_FIRST_CLASS, PostGrid::AddressVerification::ZONE_US_DOMESTIC ]   => 86,
      [ "6x4", MAILING_CLASS_FIRST_CLASS, PostGrid::AddressVerification::ZONE_CANADA ]        => 145,
      [ "6x4", MAILING_CLASS_FIRST_CLASS, PostGrid::AddressVerification::ZONE_INTERNATIONAL ] => 195,
      [ "6x9", MAILING_CLASS_FIRST_CLASS, PostGrid::AddressVerification::ZONE_US_DOMESTIC ]   => 98,
      [ "6x9", MAILING_CLASS_FIRST_CLASS, PostGrid::AddressVerification::ZONE_CANADA ]        => 165,
      [ "6x9", MAILING_CLASS_FIRST_CLASS, PostGrid::AddressVerification::ZONE_INTERNATIONAL ] => 215
    }.freeze
  }.freeze

  # Our margin, in basis points over cost. Basis points rather than a float
  # multiplier so the arithmetic below stays in integers: 1.30 is not exactly
  # representable, and a price is not a place to discover that.
  #
  # Server-side only. The user is quoted one number per card; what it is made
  # of is not theirs to see, and #base_cents / #markup_cents are deliberately
  # absent from every GraphQL type.
  MARKUP_BASIS_POINTS = 3_000
  BASIS_POINTS_PER_UNIT = 10_000

  # One piece of mail, priced. `rate_card_version` travels with it so an order
  # can record which card it was billed under (see the class note).
  Quote = Struct.new(
    :size,
    :mailing_class,
    :zone,
    :rate_card_version,
    :base_cents,
    :markup_cents,
    :total_cents,
    keyword_init: true
  )

  class << self
    extend T::Sig

    # Price one piece. Raises UnknownRateError when the rate card has no entry —
    # there is no fallback, on purpose.
    sig do
      params(
        size: String,
        zone: T.nilable(String),
        mailing_class: String,
        rate_card_version: String
      ).returns(Quote)
    end
    def quote(size:, zone:, mailing_class: DEFAULT_MAILING_CLASS, rate_card_version: CURRENT_RATE_CARD_VERSION)
      base_cents = base_cents_for(size:, zone:, mailing_class:, rate_card_version:)
      total_cents = with_markup(base_cents)

      Quote.new(
        size:,
        mailing_class:,
        zone:,
        rate_card_version:,
        base_cents:,
        markup_cents: total_cents - base_cents,
        total_cents:
      )
    end

    # Whether a piece can be priced at all, without raising. For callers that
    # need to flag an unmailable destination rather than fail the whole request.
    sig { params(size: String, zone: T.nilable(String), mailing_class: String).returns(T::Boolean) }
    def priceable?(size:, zone:, mailing_class: DEFAULT_MAILING_CLASS)
      quote(size:, zone:, mailing_class:)
      true
    rescue UnknownRateError
      false
    end

    # Every (size, mailing class, zone) the given card prices, for specs and for
    # a future "where can we mail?" surface.
    sig { params(rate_card_version: String).returns(T::Array[[ String, String, String ]]) }
    def priced_combinations(rate_card_version: CURRENT_RATE_CARD_VERSION)
      rate_card(rate_card_version).keys
    end

    private

    sig do
      params(size: String, zone: T.nilable(String), mailing_class: String, rate_card_version: String)
        .returns(Integer)
    end
    def base_cents_for(size:, zone:, mailing_class:, rate_card_version:)
      # A nil zone is an address nobody has verified yet. It is not a lookup
      # miss to work around — it is the same answer as an uncovered zone, and
      # for the same reason: we don't know what this costs.
      cents = zone && rate_card(rate_card_version)[[ size, mailing_class, zone ]]
      return cents if cents

      raise UnknownRateError,
        "No #{rate_card_version} rate for size=#{size.inspect} class=#{mailing_class.inspect} zone=#{zone.inspect}"
    end

    sig { params(version: String).returns(T::Hash[[ String, String, String ], Integer]) }
    def rate_card(version)
      RATE_CARDS[version] || raise(UnknownRateCardError, "Unknown rate card version #{version.inspect}")
    end

    # Cost plus margin, rounded **up** to the cent, always.
    #
    # Rounding to nearest would give away a fraction of a cent on half the rate
    # card, and at volume that is a real number. Integer ceiling division rather
    # than `(cents * 1.30).ceil`, so no float ever touches a price.
    sig { params(base_cents: Integer).returns(Integer) }
    def with_markup(base_cents)
      numerator = base_cents * (BASIS_POINTS_PER_UNIT + MARKUP_BASIS_POINTS)
      -(-numerator / BASIS_POINTS_PER_UNIT)
    end
  end
end
