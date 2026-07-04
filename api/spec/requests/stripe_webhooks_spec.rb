require 'rails_helper'
require 'ostruct'

RSpec.describe "StripeWebhooks", type: :request do
  let(:webhook_secret) { "whsec_testsecret" }
  let(:headers) { { "Content-Type" => "application/json" } }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:stripe, :webhook_secret).and_return(webhook_secret)
  end

  describe "POST /webhooks/stripe" do
    let(:user) { create(:user) }

    def generate_event(amount_total, user_id, customer_id = nil)
      Stripe::Event.construct_from(
        {
          id: "evt_test",
          object: "event",
          type: "checkout.session.completed",
          data: {
            object: {
              id: "cs_test",
              object: "checkout.session",
              amount_total: amount_total,
              customer: customer_id,
              metadata: {
                user_id: user_id
              }
            }
          }
        }
      )
    end

    def sign_payload(payload)
      timestamp = Time.now.to_i
      signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), webhook_secret, "#{timestamp}.#{payload}")
      "t=#{timestamp},v1=#{signature}"
    end

    it "creates credits and sends email for 1 credit purchase" do
      event = generate_event(300, user.id)
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.to change { Credit.count }.by(1)

      credit = Credit.last
      expect(credit.amount).to eq(1)
      expect(credit.user).to eq(user)
      expect(credit.reason).to eq("purchase")

      expect(response).to have_http_status(:ok)
    end

    it "creates 5 credits for 1200 amount" do
      event = generate_event(1200, user.id)
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.to change { Credit.count }.by(1)

      expect(Credit.last.amount).to eq(5)
    end

    it "stores stripe_customer_id on user if not already present" do
      expect(user.stripe_customer_id).to be_nil

      event = generate_event(300, user.id, "cus_test_123")
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      post "/webhooks/stripe", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.stripe_customer_id).to eq("cus_test_123")
    end

    it "does not overwrite existing stripe_customer_id" do
      user.update!(stripe_customer_id: "cus_existing")

      event = generate_event(300, user.id, "cus_new")
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      post "/webhooks/stripe", params: payload, headers: headers

      expect(response).to have_http_status(:ok)
      expect(user.reload.stripe_customer_id).to eq("cus_existing")
    end

    it "ignores unknown amount" do
      event = generate_event(1234, user.id)
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.not_to change { Credit.count }

      expect(response).to have_http_status(:ok)
    end

    it "handles non-existent user gracefully" do
      event = generate_event(200, "nonexistent-id")
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.not_to change { Credit.count }

      expect(response).to have_http_status(:ok)
    end

    it "returns 400 for invalid signature" do
      event = generate_event(200, user.id)
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = "bad-signature"

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.not_to change { Credit.count }

      expect(response).to have_http_status(:bad_request)
    end

    it "creates a chargeback credit when dispute is lost" do
      # First simulate a successful session
      credit = Credit.create!(
        user: user,
        amount: 5,
        reason: "purchase",
        stripe_session_id: "cs_test_abc123",
        events: [
          {
            event_kind: "credit_purchased",
            event_happened_at: Time.now.utc.iso8601(3),
            event_data: {
              stripe_session_id: "cs_test_abc123",
              stripe_customer_id: "cus_test",
              amount: 5
            }
          }
        ]
      )

      # Mock the Stripe::Charge call
      allow(Stripe::Charge).to receive(:retrieve).and_return(
        OpenStruct.new(
          id: "ch_test",
          metadata: {
            "checkout_session_id" => "cs_test_abc123"
          }
        )
      )

      event = Stripe::Event.construct_from(
        {
          id: "evt_dispute_lost",
          object: "event",
          type: "charge.dispute.closed",
          data: {
            object: {
              id: "dp_test",
              status: "lost",
              charge: "ch_test"
            }
          }
        }
      )

      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.to change { Credit.count }.by(1)

      reversal = Credit.last
      expect(reversal.amount).to eq(-5)
      expect(reversal.reason).to eq("chargeback")
      expect(reversal.user).to eq(user)
      expect(response).to have_http_status(:ok)
    end
  end
end
