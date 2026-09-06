# typed: true
# frozen_string_literal: true

# What it would cost to mail one holiday card to a set of contacts (issue #147).
#
#   HolidayCard::MailingQuote.new(card, contacts).call # => Result
#
# ## Why nothing is dropped
#
# Every contact asked about comes back, priced or flagged. A quote that silently
# skipped the four contacts with no street address would tell the user "42
# cards, $47" and then send 38 — and they would find out after paying. So an
# entry is either a price or a reason, never an omission, and the counts add up
# to what was asked for.
#
# ## Why quoting verifies
#
# The rate card keys on the destination zone, and the zone comes from PostGrid's
# address verification. An unverified contact therefore has no price — not a
# guessed one. Verifying here, and caching the verdict on the contact, is also
# the only way the "3 of your addresses are undeliverable" conversation happens
# before the user's money moves rather than after.
#
# Only contacts that need it are called: `Contact#address_verification_state`
# is cached until the address is edited, so a second quote of the same list is
# free. When PostGrid is not configured at all — the normal state of a fresh
# clone and of CI — unverified contacts come back flagged rather than raising,
# the same degradation the rest of the app gets.
#
# ## The quote is advisory
#
# It is a number to show someone, not a contract. The send flow re-prices
# inside the debit transaction (epic #135, cross-cutting rule 1), because an
# address can be edited between the quote and the send. Nothing here writes a
# price anywhere.
class HolidayCard::MailingQuote
  extend T::Sig

  MISSING_ADDRESS_REASON = "This contact doesn't have a complete mailing address."
  UNDELIVERABLE_REASON = "This address came back undeliverable."
  UNSUPPORTED_DESTINATION_REASON = "We can't mail to this destination yet."
  # PostGrid is down, rate limited, or not configured on this deploy. Temporary
  # from the user's side, and phrased as such — unlike the three above, retrying
  # is the right thing to do.
  VERIFICATION_UNAVAILABLE_REASON = "We couldn't check this address right now. Please try again in a moment."

  # One contact, priced or flagged. `total_cents` and `reason` are mutually
  # exclusive: exactly one of them is set.
  #
  # `base_cents` and the markup are deliberately not here. The GraphQL type
  # can't expose what the value object doesn't carry.
  Entry = Struct.new(:contact, :mailable, :address_verification_status, :zone, :total_cents, :reason,
                     keyword_init: true) do
    def priced?
      total_cents.present?
    end
  end

  Result = Struct.new(:entries, :total_cents, :mailable_count, :unmailable_count, :rate_card_version,
                      keyword_init: true)

  sig { params(card: ::HolidayCard, contacts: T::Enumerable[::Contact], verifier: T.untyped).void }
  def initialize(card, contacts, verifier: nil)
    @card = card
    @contacts = contacts
    @verifier = verifier
  end

  sig { returns(Result) }
  def call
    entries = @contacts.map { |contact| entry_for(contact) }
    priced = entries.select(&:priced?)

    Result.new(
      entries:,
      total_cents: priced.sum { |entry| entry.total_cents.to_i },
      mailable_count: priced.size,
      unmailable_count: entries.size - priced.size,
      rate_card_version: MailPricing::CURRENT_RATE_CARD_VERSION
    )
  end

  private

  def entry_for(contact)
    return flagged(contact, MISSING_ADDRESS_REASON) unless contact.mailable?

    ensure_verified(contact)

    case contact.address_verification_state
    when ::Contact::VERIFIED_STATUS then priced(contact)
    when ::Contact::UNDELIVERABLE_STATUS then flagged(contact, UNDELIVERABLE_REASON)
    else flagged(contact, VERIFICATION_UNAVAILABLE_REASON)
    end
  end

  # Verify a contact we have no cached verdict for, and store the result. A
  # failure is left as "still unverified" rather than re-raised: one unreachable
  # address must not cost the user the other forty-one prices.
  def ensure_verified(contact)
    return unless contact.address_verification_state == ::Contact::UNVERIFIED_STATUS
    return unless PostGrid.configured?

    contact.apply_address_verification!(verifier.verify_contact(contact))
  rescue PostGrid::Error => e
    # PostGrid's message can quote the address back at us, so only the class is
    # logged — the same rule Mutations::VerifyContactAddress follows.
    Rails.logger.warn("[PostGrid] quote verification failed contact=#{contact.id} error=#{e.class}")
  end

  def priced(contact)
    quote = MailPricing.quote(size: @card.size, zone: contact.address_zone)

    Entry.new(
      contact:,
      mailable: true,
      address_verification_status: contact.address_verification_state,
      zone: contact.address_zone,
      total_cents: quote.total_cents,
      reason: nil
    )
  rescue MailPricing::UnknownRateError
    # A verified address in a zone the rate card doesn't cover. Never a fallback
    # to the domestic price — see MailPricing's class note.
    flagged(contact, UNSUPPORTED_DESTINATION_REASON)
  end

  def flagged(contact, reason)
    Entry.new(
      contact:,
      mailable: contact.mailable?,
      address_verification_status: contact.address_verification_state,
      zone: contact.address_zone,
      total_cents: nil,
      reason:
    )
  end

  # Built lazily so a quote over already-verified contacts — the common case on
  # a second look at the same list — constructs no PostGrid client at all.
  def verifier
    @verifier ||= PostGrid::AddressVerification.new
  end
end
