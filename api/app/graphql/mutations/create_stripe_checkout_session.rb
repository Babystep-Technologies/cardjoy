# typed: true

module Mutations
  # Opens a Stripe Checkout session for a credit purchase. The product is an
  # explicit argument, carried into the session metadata and read back by
  # StripeWebhooksController to pick the ledger the money lands in.
  class CreateStripeCheckoutSession < BaseMutation
    UNKNOWN_PRODUCT_ERROR = "Unknown product"
    MISSING_PRICE_ID_ERROR = "A price is required"

    argument :price_id, String, required: false
    # Which product is being bought — see StripeCheckout::PRODUCTS. Omitted
    # means the credit product, so existing clients are unaffected.
    argument :product, String, required: false
    # Buy into an organization's shared pool instead of your personal balance.
    # Admin-only: it spends money the whole team then draws from.
    argument :organization_id, ID, required: false

    field :checkout_url, String, null: true
    field :error, String, null: true

    def resolve(price_id: nil, product: nil, organization_id: nil)
      user = context[:current_user]
      raise GraphQL::ExecutionError, "Unauthorized" unless user

      product = product.presence || StripeCheckout::CREDITS_PRODUCT
      return { error: UNKNOWN_PRODUCT_ERROR } unless StripeCheckout::PRODUCTS.include?(product)

      organization = nil
      if organization_id.present?
        organization = Organization.find_by(id: organization_id)
        return { error: NOT_AUTHORIZED_ERROR } unless org_admin?(organization)
      end

      return { error: MISSING_PRICE_ID_ERROR } if price_id.blank?

      line_item = { price: price_id, quantity: 1 }

      frontend_url = Rails.application.credentials.dig(:frontend_url)
      raise GraphQL::ExecutionError, "Frontend URL not configured" unless frontend_url

      # StripeWebhooksController reads this back on checkout.session.completed
      # to decide which ledger the purchase lands in.
      metadata = { user_id: user.id, product: product }
      metadata[:organization_id] = organization.id if organization

      session = Stripe::Checkout::Session.create(
        payment_method_types: [ "card" ],
        mode: "payment",
        line_items: [ line_item ],
        success_url: "#{frontend_url}/buy_credits/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{frontend_url}/buy_credits/cancel",
        metadata: metadata
      )

      { checkout_url: session.url }
    rescue => e
      { error: e.message }
    end
  end
end
