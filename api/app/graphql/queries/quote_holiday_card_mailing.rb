# typed: true
# frozen_string_literal: true

module Queries
  # What it would cost to mail one holiday card to a set of contacts (#147).
  #
  # **The number this returns is advisory.** The send flow re-prices inside the
  # transaction that debits the postage wallet (epic #135, cross-cutting rule 1),
  # because an address — and therefore a zone, and therefore a price — can be
  # edited between the quote and the send. There is no mutation argument
  # anywhere that accepts a price from a client. Do not build a UI that treats
  # `totalCents` as something the server has committed to.
  #
  # It is a query rather than a mutation despite writing: quoting caches an
  # address verification on any contact that lacks one. That write is a cache
  # fill, not a state change the caller asked for, and making this a mutation
  # would put a read in the write half of every client's cache policy.
  class QuoteHolidayCardMailing < BaseQuery
    # A ceiling on how many addresses one request may verify, since each
    # uncached one is a PostGrid round trip. Comfortably above a large family
    # card list; it exists so a single query can't be turned into a hundred
    # seconds of outbound HTTP.
    MAX_CONTACTS = 500

    TOO_MANY_CONTACTS_ERROR = "Quote at most #{MAX_CONTACTS} contacts at a time"

    type Types::HolidayCardMailingQuoteType, null: false

    argument :holiday_card_id, ID, required: true,
      description: "The card's `externalId`."
    argument :contact_ids, [ ID ], required: true,
      description: "The recipients to price. Duplicates are collapsed; every distinct id comes back as an entry."

    def resolve(holiday_card_id:, contact_ids:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      ids = contact_ids.map(&:to_s).uniq
      raise GraphQL::ExecutionError, TOO_MANY_CONTACTS_ERROR if ids.size > MAX_CONTACTS

      quote(card_for(user, holiday_card_id), contacts_for(user, ids), user)
    end

    private

    # Someone else's card and a card that doesn't exist give the same answer, so
    # a stranger can't use this to learn which `externalId`s are real.
    def card_for(user, holiday_card_id)
      card = ::HolidayCard.find_by(external_id: holiday_card_id)
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless card && card.user_id == user.id

      card
    end

    # Every requested id must be one of the caller's contacts. A partial match
    # is denied rather than quietly quoted for the subset — asking about
    # somebody else's contact is not a typo to work around, and a quote missing
    # rows the caller asked for would misreport the total.
    def contacts_for(user, ids)
      by_id = user.contacts.where(id: ids).index_by { |contact| contact.id.to_s }
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless by_id.size == ids.size

      ids.map { |id| by_id.fetch(id) }
    end

    def quote(card, contacts, user)
      result = ::HolidayCard::MailingQuote.new(card, contacts).call

      {
        entries: result.entries,
        total_cents: result.total_cents,
        mailable_count: result.mailable_count,
        unmailable_count: result.unmailable_count,
        postage_balance_cents: user.postage_balance_cents
      }
    end
  end
end
