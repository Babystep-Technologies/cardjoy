# typed: true

# A user's postage wallet — the same append-only ledger as Credit, denominated
# in US cents rather than whole credits (issue #145).
#
# It is separate from `credits` on purpose. A credit is one digital card and
# sells for a couple of dollars; a 6x4 postcard costs well under a dollar to
# print and mail, and the price moves with size and destination. Charging one
# existing credit per postcard would be a ~200% markup with two or three price
# buckets, so physical mail gets its own wallet and its own arithmetic. The
# existing product is untouched.
#
# Positive rows put cents in (a top-up, a promo grant, a refund), negative rows
# take them out (a piece of mail). Nothing is ever edited or deleted: a refund
# is a new positive row, so the history stays readable.
#
# Written through User#spend_postage! and User#refund_postage!, which hold the
# balance check and the row lock.
class PostageCredit < ApplicationRecord
  include CreditLedger

  belongs_to :user

  scope :available, -> { where("amount_cents > 0") }

  # What a top-up is allowed to be worth, in US cents (#146). Postage is bought
  # in dollar amounts rather than in units, and a tier credits its face value —
  # $10 in, 1000¢ in the wallet — so the sold value and the ledger value are the
  # same number and there is no exchange rate to reason about.
  #
  # The list lives here, on the server, because both ends need it and neither
  # can be the client: Mutations::CreateStripeCheckoutSession validates the
  # requested tier before charging, and StripeWebhooksController validates it
  # again before crediting. A client that names its own amount is rejected.
  TOP_UP_TIERS_CENTS = [ 1_000, 2_500, 5_000 ].freeze

  EVENT_KINDS = %w[
    postage_purchased
    postage_spent_on_mail
    postage_refunded
    postage_promo_grant
    postage_reversed_due_to_chargeback
    postage_admin_adjustment
  ].freeze

  # A zero row moves nothing and only pollutes the ledger, so it is rejected
  # rather than silently written. (The column is `null: false` in the table;
  # this catches the other half.)
  validates :amount_cents, presence: true, numericality: { other_than: 0, only_integer: true }

  private

  def allowed_event_kinds
    EVENT_KINDS
  end
end
