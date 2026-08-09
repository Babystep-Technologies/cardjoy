# typed: true

module Mutations
  class CreateStripeCheckoutSession < BaseMutation
    argument :price_id, String, required: true
    # Buy into an organization's shared pool instead of your personal balance.
    # Admin-only: it spends money the whole team then draws from.
    argument :organization_id, ID, required: false

    field :checkout_url, String, null: true
    field :error, String, null: true

    def resolve(price_id:, organization_id: nil)
      user = context[:current_user]
      raise GraphQL::ExecutionError, "Unauthorized" unless user

      organization = nil
      if organization_id.present?
        organization = Organization.find_by(id: organization_id)
        return { error: NOT_AUTHORIZED_ERROR } unless org_admin?(organization)
      end

      frontend_url = Rails.application.credentials.dig(:frontend_url)
      raise GraphQL::ExecutionError, "Frontend URL not configured" unless frontend_url

      # StripeWebhooksController reads this back on checkout.session.completed
      # to decide which ledger the purchase lands in.
      metadata = { user_id: user.id }
      metadata[:organization_id] = organization.id if organization

      session = Stripe::Checkout::Session.create(
        payment_method_types: [ "card" ],
        mode: "payment",
        line_items: [ {
          price: price_id,
          quantity: 1
        } ],
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
