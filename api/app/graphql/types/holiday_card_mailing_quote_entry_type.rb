# typed: true
# frozen_string_literal: true

module Types
  # One recipient in a mailing quote (#147) — either a price or the reason there
  # isn't one, never both and never neither.
  #
  # `baseCents` and the markup are absent by design. The user is quoted one
  # number per card; what it is made of is ours.
  class HolidayCardMailingQuoteEntryType < Types::BaseObject
    description "What mailing this card to one contact would cost, or why it can't be mailed."

    # The whole contact rather than a loose id and name, so the recipient list
    # can render addresses and fix a flagged one without a second round trip.
    field :contact, Types::ContactType, null: false

    field :mailable, Boolean, null: false,
      description: "Whether the contact has the address fields a carrier needs."
    field :address_verification_status, String, null: false,
      description: 'As of this quote: "verified", "undeliverable", or "unverified".'
    field :zone, String, null: true,
      description: "The destination pricing zone, once the address has been verified."

    field :total_cents, Integer, null: true,
      description: "What this piece costs the user, in US cents. Null when the contact can't be mailed."
    field :reason, String, null: true,
      description: "Why there is no price. Null for a priced entry."
  end
end
