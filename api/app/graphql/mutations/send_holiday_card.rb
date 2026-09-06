# typed: true
# frozen_string_literal: true

module Mutations
  # Mail a holiday card to a list of contacts (issue #148) — the point where a
  # design, a list of addresses, a price, and a wallet meet an external service
  # that prints things.
  #
  # ## What happens, in order
  #
  # 1. **Preconditions, before any money moves.** The card is the caller's, its
  #    proof is approved *and* still current, every contact is the caller's and
  #    has a complete address, and a live PostGrid key exists. Each of these
  #    rejects the whole request and debits nothing.
  # 2. **Verification, outside the transaction.** Any contact with no cached
  #    PostGrid verdict is verified now, through the same
  #    `HolidayCard::MailingQuote` the quote query uses. This is a network call,
  #    so it happens before the transaction opens, and an address that comes
  #    back undeliverable stops the send rather than being charged for.
  # 3. **One transaction: re-price, lock, debit, write.** Prices are looked up
  #    again from `MailPricing` — there is no argument anywhere that accepts a
  #    price, so the client's number is not merely ignored, it is unsendable.
  #    The user row is locked, the total checked against the balance, and one
  #    debit plus one order row written per recipient.
  # 4. **Nothing submitted.** A `HolidayCardMailSubmissionJob` per order is
  #    enqueued only after the transaction has committed.
  #
  # ## Why per-order debits
  #
  # One negative `postage_credits` row per piece, not one for the batch. When a
  # single postcard is rejected by PostGrid, the refund is exactly that row's
  # cents — no arithmetic, no apportioning a batch total across recipients whose
  # prices differ by destination, and a ledger that reads as "40 cards out, 2
  # back" rather than as a total the user has to reconcile themselves.
  #
  # ## Why it returns immediately with everything `pending`
  #
  # Nothing has been submitted yet, and there is no honest way to report a
  # per-piece outcome synchronously. The client reads status per order
  # afterwards (`myHolidayCardOrders`). Partial failure is expected, not
  # exceptional: 38 pieces can succeed while 2 fail and refund themselves.
  class SendHolidayCard < BaseMutation
    # The wallet can't cover this send. Carries the user-facing sentence and
    # exists to unwind the transaction from inside — see #check_balance!.
    class ShortfallError < StandardError; end

    # A ceiling on one send. Each recipient is a PostGrid submission and a
    # ledger row; comfortably above a large family card list, and low enough
    # that one request can't queue an unbounded amount of outbound printing.
    MAX_RECIPIENTS = 500

    NO_RECIPIENTS_ERROR = "Pick at least one recipient."
    TOO_MANY_RECIPIENTS_ERROR = "Send to at most #{MAX_RECIPIENTS} recipients at a time."
    NO_PROOF_ERROR = "Approve a proof of this card before sending it."
    STALE_PROOF_ERROR = "This card has changed since its proof was approved. " \
                        "Generate a new proof and approve it before sending."
    # No live key on this deploy. Mailing is optional app-wide (CLAUDE.md), so
    # it switches off rather than raising out of the client.
    UNAVAILABLE_ERROR = "Sending cards by post is unavailable right now. Please try again later."
    UNKNOWN_MAILING_CLASS_ERROR = "That's not a mailing class we offer."

    argument :holiday_card_id, ID, required: true,
      description: "The card's `externalId`."
    argument :contact_ids, [ ID ], required: true,
      description: "Who to mail it to. Duplicates are collapsed — nobody is charged twice for one send."
    argument :mailing_class, String, required: false,
      description: "Defaults to `first_class`, the only class currently offered."

    field :orders, [ Types::HolidayCardMailOrderType ], null: true,
      description: "One order per recipient, all `pending`. Null when the send was rejected."
    field :total_charged_cents, Integer, null: true,
      description: "What was debited from the postage wallet, in US cents."
    field :errors, [ String ], null: false

    def resolve(holiday_card_id:, contact_ids:, mailing_class: nil)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      mailing_class = mailing_class.presence || MailPricing::DEFAULT_MAILING_CLASS
      return failure(UNKNOWN_MAILING_CLASS_ERROR) unless MailPricing::MAILING_CLASSES.include?(mailing_class)

      ids = contact_ids.map(&:to_s).uniq
      return failure(NO_RECIPIENTS_ERROR) if ids.empty?
      return failure(TOO_MANY_RECIPIENTS_ERROR) if ids.size > MAX_RECIPIENTS
      # No live key means nothing here could ever be printed. Checked before the
      # card lookup so an unconfigured deploy gives one honest answer rather
      # than a not-found for a card that exists.
      return failure(UNAVAILABLE_ERROR) unless PostGrid.configured?(mode: ::HolidayCard::MailSubmission::MODE)

      card = authorized_card(user, holiday_card_id)
      return failure(NOT_AUTHORIZED_ERROR) unless card

      send_to(user, card, ids, mailing_class)
    end

    private

    # Someone else's card and a card that doesn't exist give the same answer, so
    # a stranger can't use this to learn which `externalId`s are real.
    def authorized_card(user, holiday_card_id)
      card = ::HolidayCard.find_by(external_id: holiday_card_id)
      card if card && card.user_id == user.id
    end

    def send_to(user, card, ids, mailing_class)
      # The gate the whole proof mechanism exists to provide. Told apart because
      # they ask different things of the user: one has never approved anything,
      # the other approved a card that has since moved.
      return failure(NO_PROOF_ERROR) if card.proof_approved_at.blank?
      return failure(STALE_PROOF_ERROR) unless card.proof_current?

      contacts = authorized_contacts(user, ids)
      return failure(NOT_AUTHORIZED_ERROR) unless contacts

      # Verifies anything unverified and flags anything unpriceable. Outside the
      # transaction on purpose — it makes PostGrid calls.
      quote = ::HolidayCard::MailingQuote.new(card, contacts).call
      blocked = quote.entries.reject(&:priced?)
      return failure(recipient_errors(blocked)) if blocked.any?

      charge_and_enqueue(user, card, contacts, mailing_class)
    end

    # Every requested id must be one of the caller's contacts. A partial match
    # is rejected rather than quietly sending to the subset: asking about
    # somebody else's contact is not a typo to route around, and silently
    # dropping a recipient from a paid send is the exact failure this epic's
    # quote flow is built to avoid.
    def authorized_contacts(user, ids)
      by_id = user.contacts.where(id: ids).index_by { |contact| contact.id.to_s }
      return nil unless by_id.size == ids.size

      ids.map { |id| by_id.fetch(id) }
    end

    # One sentence per unsendable recipient, named, so the user can go and fix
    # the right address instead of being told "something is wrong".
    def recipient_errors(entries)
      entries.map { |entry| "#{entry.contact.name}: #{entry.reason}" }
    end

    def charge_and_enqueue(user, card, contacts, mailing_class)
      orders = ActiveRecord::Base.transaction do
        # Held for the rest of the transaction, so two concurrent sends can't
        # both pass the balance check below and overdraw the wallet. Taken
        # before the balance is read, not after.
        user.lock!

        quotes = price(card, contacts, mailing_class)
        # Raised rather than returned: `return` out of a transaction block is
        # ambiguous about whether it commits, and this one has to roll back
        # every row it has written. Caught immediately below.
        check_balance!(user, quotes)

        # The transaction's value, so the orders reach the code below without a
        # variable that is nil for the whole of the block that fills it.
        quotes.map { |contact, quote| create_order(user, card, contact, quote) }
      end

      enqueue(orders)
      { orders:, total_charged_cents: orders.sum(&:charged_cents), errors: [] }
    rescue ShortfallError => e
      failure(e.message)
    rescue MailPricing::UnknownRateError
      # Unreachable by way of the MailingQuote pass above, which flags exactly
      # these. Kept because the alternative to a rescue here is a 500 on a
      # money path if the two ever drift apart.
      failure("We can't mail to one of these destinations yet.")
    end

    # Re-priced from `MailPricing` inside the transaction. The quote the client
    # was shown is not consulted and is not accepted as an argument: an address
    # — and therefore a zone, and therefore a price — can be edited between
    # looking and sending.
    def price(card, contacts, mailing_class)
      contacts.map do |contact|
        [ contact, MailPricing.quote(size: card.size, zone: contact.address_zone, mailing_class:) ]
      end
    end

    def create_order(user, card, contact, quote)
      credit = user.spend_postage!(
        cents: quote.total_cents,
        reason: "holiday_card_mail",
        event_kind: "postage_spent_on_mail",
        event_data: { "holiday_card_id" => card.id, "contact_id" => contact.id }
      )

      ::HolidayCardMailOrder.create!(
        holiday_card: card,
        user:,
        contact:,
        recipient_snapshot: ::HolidayCardMailOrder.snapshot_for(contact),
        size: card.size,
        mailing_class: quote.mailing_class,
        zone: quote.zone,
        rate_card_version: quote.rate_card_version,
        base_cents: quote.base_cents,
        charged_cents: quote.total_cents,
        postage_credit: credit,
        # Minted once, here, and never regenerated. It is what makes a retry of
        # the submission safe: PostGrid returns the original postcard for a
        # repeated key instead of printing a second one.
        idempotency_key: SecureRandom.uuid,
        status: ::HolidayCardMailOrder::PENDING
      )
    end

    # After commit, never inside. An enqueue inside the transaction can be
    # picked up by a worker before the row it names is visible — and with
    # GoodJob running in-process, before it exists at all.
    def enqueue(orders)
      orders.each { |order| HolidayCardMailSubmissionJob.perform_later(order.id) }
    end

    # Names the shortfall in cents, because "add more postage" without a number
    # is not actionable — the client needs it to size the top-up.
    def check_balance!(user, quotes)
      total_cents = quotes.sum { |_contact, quote| quote.total_cents }
      balance_cents = user.postage_balance_cents
      shortfall_cents = total_cents - balance_cents
      return unless shortfall_cents.positive?

      raise ShortfallError,
        "Not enough postage. This send costs #{total_cents} cents and your wallet has #{balance_cents} cents — " \
        "you're #{shortfall_cents} cents short."
    end

    def failure(errors)
      { orders: nil, total_charged_cents: nil, errors: Array(errors) }
    end
  end
end
