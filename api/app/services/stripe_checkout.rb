# typed: true

# The vocabulary of a Stripe Checkout session's `metadata`: written by
# Mutations::CreateStripeCheckoutSession when the session is created, read back
# by StripeWebhooksController when Stripe reports it completed.
#
# It lives apart from both because it *is* the contract between them. The two
# halves run minutes apart in different processes, and when the webhook fires
# this hash is all it has to tell a credit purchase from a postage top-up.
#
# `product` is an explicit discriminator rather than something inferred from the
# price id (#146). Price ids get added and rotated in the Stripe dashboard, and
# a mis-mapped price would silently credit the wrong ledger; an unrecognized
# `product` is refused instead.
module StripeCheckout
  # The ordinary credit product — digital cards, priced by the existing table in
  # StripeWebhooksController.
  CREDITS_PRODUCT = "credits"

  # A postage wallet top-up: cents into `postage_credits`, in the amount named
  # by the session's `postage_cents` metadata. See
  # PostageCredit::TOP_UP_TIERS_CENTS.
  POSTAGE_PRODUCT = "postage"

  PRODUCTS = [ CREDITS_PRODUCT, POSTAGE_PRODUCT ].freeze

  # Which product a completed session was for.
  #
  # A session with no `product` key is a credit purchase: sessions created
  # before #146 shipped are still in flight when it deploys, and they have to
  # keep working. Returns the raw string for anything else so the caller can
  # refuse it by name rather than silently guessing a ledger.
  def self.product_for(metadata)
    value = metadata && metadata["product"]
    value.presence || CREDITS_PRODUCT
  end
end
