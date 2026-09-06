# typed: true
# frozen_string_literal: true

module Types
  # An advisory price for mailing one holiday card to a list of contacts (#147).
  #
  # **Advisory, not a contract.** The send flow re-prices inside the transaction
  # that debits the wallet, because an address can be edited between the quote
  # and the send. A client never sends a price back — there is no mutation
  # argument that would accept one.
  class HolidayCardMailingQuoteType < Types::BaseObject
    description <<~DESC.strip
      An estimate of what mailing this card to these contacts would cost.

      Advisory only: the send flow re-prices at charge time, so treat `totalCents` as
      a number to show someone, not as a quoted price the server has committed to.
    DESC

    field :entries, [ Types::HolidayCardMailingQuoteEntryType ], null: false,
      description: "One entry per contact asked about, in the order given. Nothing is dropped."

    field :total_cents, Integer, null: false,
      description: "The sum over the mailable recipients only, in US cents. Zero when none are mailable."
    field :mailable_count, Integer, null: false,
      description: "How many entries carry a price."
    field :unmailable_count, Integer, null: false,
      description: "How many entries carry a reason instead."

    field :postage_balance_cents, Integer, null: false,
      description: "The caller's postage wallet balance, so the client can show the shortfall directly."
  end
end
