# typed: true

module Mutations
  class CreateStripeCheckoutSession < BaseMutation
    argument :price_id, String, required: true

    field :checkout_url, String, null: true
    field :error, String, null: true

    def resolve(price_id:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, "Unauthorized" unless user

      frontend_url = Rails.application.credentials.dig(:frontend_url)
      raise GraphQL::ExecutionError, "Frontend URL not configured" unless frontend_url

      session = Stripe::Checkout::Session.create(
        payment_method_types: [ "card" ],
        mode: "payment",
        line_items: [ {
          price: price_id,
          quantity: 1
        } ],
        success_url: "#{frontend_url}/buy_credits/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "#{frontend_url}/buy_credits/cancel",
        metadata: {
          user_id: user.id
        }
      )

      { checkout_url: session.url }
    rescue => e
      { error: e.message }
    end
  end
end
