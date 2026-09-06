# typed: true

module Mutations
  # Opens a Stripe Checkout session for one of two products: the ordinary credit
  # product, or a postage wallet top-up (#146). Which one is an explicit
  # argument, carried into the session metadata and read back by
  # StripeWebhooksController to pick the ledger the money lands in.
  class CreateStripeCheckoutSession < BaseMutation
    UNKNOWN_PRODUCT_ERROR = "Unknown product"
    MISSING_PRICE_ID_ERROR = "A price is required"
    INVALID_TOP_UP_ERROR = "Not a valid postage top-up amount"
    POSTAGE_IS_PERSONAL_ERROR = "The postage wallet is personal and cannot be bought into an organization"

    # Required for the credit product, unused for postage: a top-up's price is
    # the tier itself, priced inline below.
    argument :price_id, String, required: false
    # Which product is being bought — see StripeCheckout::PRODUCTS. Omitted
    # means the credit product, so existing clients are unaffected.
    argument :product, String, required: false
    # For `product: "postage"` only: the tier being bought, in US cents. It is
    # validated against PostageCredit::TOP_UP_TIERS_CENTS, so this argument
    # picks from the server's price list rather than naming an amount.
    argument :top_up_cents, Integer, required: false
    # Buy into an organization's shared pool instead of your personal balance.
    # Admin-only: it spends money the whole team then draws from.
    argument :organization_id, ID, required: false

    field :checkout_url, String, null: true
    field :error, String, null: true

    def resolve(price_id: nil, product: nil, top_up_cents: nil, organization_id: nil)
      user = context[:current_user]
      raise GraphQL::ExecutionError, "Unauthorized" unless user

      product = product.presence || StripeCheckout::CREDITS_PRODUCT
      return { error: UNKNOWN_PRODUCT_ERROR } unless StripeCheckout::PRODUCTS.include?(product)

      organization = nil
      if organization_id.present?
        # The postage wallet hangs off a user, not an organization, so there is
        # no pool to buy into. Refuse rather than quietly dropping the org and
        # topping up the buyer's personal wallet with team money.
        return { error: POSTAGE_IS_PERSONAL_ERROR } if postage?(product)

        organization = Organization.find_by(id: organization_id)
        return { error: NOT_AUTHORIZED_ERROR } unless org_admin?(organization)
      end

      line_item = if postage?(product)
        return { error: INVALID_TOP_UP_ERROR } unless PostageCredit::TOP_UP_TIERS_CENTS.include?(top_up_cents)

        postage_line_item(top_up_cents)
      else
        return { error: MISSING_PRICE_ID_ERROR } if price_id.blank?

        { price: price_id, quantity: 1 }
      end

      frontend_url = Rails.application.credentials.dig(:frontend_url)
      raise GraphQL::ExecutionError, "Frontend URL not configured" unless frontend_url

      # StripeWebhooksController reads this back on checkout.session.completed
      # to decide which ledger the purchase lands in.
      metadata = { user_id: user.id, product: product }
      metadata[:organization_id] = organization.id if organization
      metadata[:postage_cents] = top_up_cents if postage?(product)

      return_path = postage?(product) ? "buy_postage" : "buy_credits"

      session = Stripe::Checkout::Session.create(
        payment_method_types: [ "card" ],
        mode: "payment",
        line_items: [ line_item ],
        success_url: "#{frontend_url}/#{return_path}/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{frontend_url}/#{return_path}/cancel",
        metadata: metadata
      )

      { checkout_url: session.url }
    rescue => e
      { error: e.message }
    end

    private

    def postage?(product)
      product == StripeCheckout::POSTAGE_PRODUCT
    end

    # Priced inline rather than against a Stripe price id. A top-up credits its
    # face value, so the amount charged and the amount banked have to be the
    # same number; building the line item from the tier leaves no dashboard
    # price for the two to drift apart in.
    def postage_line_item(cents)
      {
        price_data: {
          currency: "usd",
          unit_amount: cents,
          product_data: {
            name: "CardJoy postage — #{ActiveSupport::NumberHelper.number_to_currency(cents / 100.0)}"
          }
        },
        quantity: 1
      }
    end
  end
end
