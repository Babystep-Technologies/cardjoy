require 'rails_helper'
require 'ostruct'

RSpec.describe "StripeWebhooks", type: :request do
  let(:webhook_secret) { "whsec_testsecret" }
  let(:headers) { { "Content-Type" => "application/json" } }

  before do
    # `and_call_original` first: this file is the first thing to touch
    # credentials in some orderings, and lazily autoloading a model that reads
    # storage.yml would otherwise blow up on the unstubbed key.
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:stripe, :webhook_secret).and_return(webhook_secret)
  end

  describe "POST /webhooks/stripe" do
    let(:user) { create(:user) }

    def generate_event(
      amount_total, user_id, customer_id = nil,
      organization_id: nil, session_id: "cs_test", product: :unset, postage_cents: nil
    )
      # A personal purchase carries no organization_id key at all, which is
      # what Stripe sends back for the metadata we set on the session.
      #
      # `product: :unset` reproduces a session created before #146 shipped —
      # no product key at all — which must still mean the credit product.
      metadata = { user_id: user_id }
      metadata[:product] = product unless product == :unset
      # Stripe hands metadata back as strings whatever we set it to, so the
      # amount arrives at the webhook as "2500", never 2500.
      metadata[:postage_cents] = postage_cents.to_s if postage_cents
      metadata[:organization_id] = organization_id if organization_id

      Stripe::Event.construct_from(
        {
          id: "evt_test",
          object: "event",
          type: "checkout.session.completed",
          data: {
            object: {
              id: session_id,
              object: "checkout.session",
              amount_total: amount_total,
              customer: customer_id,
              metadata: metadata
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

    # Sessions created after #146 tag themselves; sessions created before it
    # carry no product key at all (every other credit example here). Both are
    # the credit product, and neither touches the postage wallet.
    it "creates credits for a session that names the credit product explicitly" do
      event = generate_event(300, user.id, product: "credits")
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.to change { Credit.count }.by(1).and change { PostageCredit.count }.by(0)

      expect(Credit.last.amount).to eq(1)
    end

    it "leaves the postage wallet alone for a credit purchase" do
      event = generate_event(1200, user.id)
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.not_to change { PostageCredit.count }

      expect(user.postage_balance_cents).to eq(0)
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
      }.to change { Credit.count }.by(1).and change { PostageCredit.count }.by(0)

      reversal = Credit.last
      expect(reversal.amount).to eq(-5)
      expect(reversal.reason).to eq("chargeback")
      expect(reversal.user).to eq(user)
      expect(response).to have_http_status(:ok)
    end

    it "leaves every organization pool alone for a personal purchase" do
      create(:organization)

      event = generate_event(300, user.id)
      payload = event.to_json
      headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

      expect {
        post "/webhooks/stripe", params: payload, headers: headers
      }.to change { Credit.count }.by(1)

      expect(OrganizationCredit.count).to eq(0)
    end

    context "when the session is a postage top-up" do
      # Created up front: a new user comes with a signup credit, and creating
      # them lazily inside an `expect { }` block would count as the credit
      # ledger changing.
      before { user }

      # The amount charged is the tier, so amount_total and the metadata agree —
      # but the ledger is written from the metadata, which is the field the
      # mutation validated against the price list.
      def post_top_up(cents: 2500, session_id: "cs_postage", user_id: user.id)
        event = generate_event(
          cents, user_id, "cus_test",
          session_id: session_id, product: "postage", postage_cents: cents
        )
        payload = event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)
        post "/webhooks/stripe", params: payload, headers: headers
      end

      it "banks cents in the wallet and leaves the credit ledger alone" do
        expect { post_top_up }.to change { PostageCredit.count }.by(1)
          .and change { Credit.count }.by(0)

        row = PostageCredit.last
        expect(row.user).to eq(user)
        expect(row.amount_cents).to eq(2500)
        expect(row.reason).to eq("purchase")
        expect(row.stripe_session_id).to eq("cs_postage")
        expect(row.events.first["event_kind"]).to eq("postage_purchased")
        expect(row.events.first["event_data"]["amount_cents"]).to eq(2500)

        expect(user.postage_balance_cents).to eq(2500)
        expect(user.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
        expect(response).to have_http_status(:ok)
      end

      it "does not double-credit when Stripe redelivers the same session" do
        post_top_up
        expect { post_top_up }.not_to change { PostageCredit.count }

        expect(user.postage_balance_cents).to eq(2500)
        expect(response).to have_http_status(:ok)
      end

      it "banks a second, distinct top-up" do
        post_top_up
        expect { post_top_up(cents: 1000, session_id: "cs_postage_2") }
          .to change { PostageCredit.count }.by(1)

        expect(user.postage_balance_cents).to eq(3500)
      end

      it "banks nothing for an amount we do not sell" do
        expect { post_top_up(cents: 4237) }.to change { PostageCredit.count }.by(0)
          .and change { Credit.count }.by(0)

        expect(response).to have_http_status(:ok)
      end

      it "banks nothing when the amount is missing entirely" do
        event = generate_event(2500, user.id, "cus_test", product: "postage")
        payload = event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.to change { PostageCredit.count }.by(0).and change { Credit.count }.by(0)

        expect(response).to have_http_status(:ok)
      end

      it "banks nothing for a product we do not recognize" do
        event = generate_event(1200, user.id, "cus_test", product: "bananas")
        payload = event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.to change { PostageCredit.count }.by(0).and change { Credit.count }.by(0)

        expect(response).to have_http_status(:ok)
      end

      # The product decides the ledger, not the amount: a charge whose total
      # happens to sit in the credit price table still buys postage only.
      it "does not fall back to credits when the charge total matches a credit price" do
        event = generate_event(
          1200, user.id, "cus_test",
          session_id: "cs_postage_1200", product: "postage", postage_cents: 1000
        )
        payload = event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.to change { PostageCredit.count }.by(1).and change { Credit.count }.by(0)

        expect(PostageCredit.last.amount_cents).to eq(1000)
      end

      it "does nothing for a user who no longer exists" do
        expect { post_top_up(user_id: "nonexistent-id") }.not_to change { PostageCredit.count }
        expect(response).to have_http_status(:ok)
      end

      it "reverses against the wallet when the dispute is lost, leaving credit ledgers untouched" do
        post_top_up
        purchase = PostageCredit.last

        allow(Stripe::Charge).to receive(:retrieve).and_return(
          OpenStruct.new(id: "ch_test", metadata: { "checkout_session_id" => "cs_postage" })
        )

        payload = dispute_event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.to change { PostageCredit.count }.by(1).and change { Credit.count }.by(0)

        reversal = PostageCredit.last
        expect(reversal.amount_cents).to eq(-2500)
        expect(reversal.reason).to eq("chargeback")
        expect(reversal.user).to eq(user)
        expect(reversal.events.first["event_kind"]).to eq("postage_reversed_due_to_chargeback")
        expect(reversal.events.first["event_data"]["original_credit_id"]).to eq(purchase.id)
        expect(user.postage_balance_cents).to eq(0)

        # Replaying the dispute must not reverse twice.
        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.not_to change { PostageCredit.count }
      end

      # The money may already be out the door on mail that is printing. The
      # reversal still writes in full and the wallet goes negative: they owe it,
      # and spend_postage! blocks further sends until it is back above water.
      it "drives the wallet negative rather than clamping when the money is already spent" do
        post_top_up
        user.with_lock do
          user.spend_postage!(cents: 2000, reason: "mail", event_kind: "postage_spent_on_mail")
        end

        allow(Stripe::Charge).to receive(:retrieve).and_return(
          OpenStruct.new(id: "ch_test", metadata: { "checkout_session_id" => "cs_postage" })
        )

        payload = dispute_event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)
        post "/webhooks/stripe", params: payload, headers: headers

        expect(response).to have_http_status(:ok)
        expect(user.postage_balance_cents).to eq(-2000)
        expect {
          user.with_lock { user.spend_postage!(cents: 100, reason: "mail", event_kind: "postage_spent_on_mail") }
        }.to raise_error(User::InsufficientPostageError)
      end

      def dispute_event
        Stripe::Event.construct_from(
          {
            id: "evt_dispute_lost",
            object: "event",
            type: "charge.dispute.closed",
            data: { object: { id: "dp_test", status: "lost", charge: "ch_test" } }
          }
        )
      end
    end

    context "when the session is tagged with an organization" do
      let(:organization) { create(:organization, created_by: user) }

      before { create(:organization_membership, :admin, organization:, user:) }

      def post_event(**kwargs)
        event = generate_event(1200, user.id, "cus_test", organization_id: organization.id, **kwargs)
        payload = event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)
        post "/webhooks/stripe", params: payload, headers: headers
      end

      it "credits the pool and not the purchaser's personal balance" do
        expect { post_event }.to change { OrganizationCredit.count }.by(1)
          .and change { Credit.count }.by(0)

        credit = OrganizationCredit.last
        expect(credit.organization).to eq(organization)
        expect(credit.amount).to eq(5)
        expect(credit.reason).to eq("purchase")
        expect(credit.stripe_session_id).to eq("cs_test")
        expect(credit.events.first["event_kind"]).to eq("org_credit_purchased")

        expect(organization.credit_balance).to eq(5)
        expect(user.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
        expect(response).to have_http_status(:ok)
      end

      it "does not double-credit when Stripe redelivers the same session" do
        post_event
        expect(response).to have_http_status(:ok)

        expect { post_event }.not_to change { OrganizationCredit.count }

        expect(organization.credit_balance).to eq(5)
        expect(response).to have_http_status(:ok)
      end

      it "credits a second, distinct purchase" do
        post_event
        expect { post_event(session_id: "cs_test_2") }.to change { OrganizationCredit.count }.by(1)

        expect(organization.credit_balance).to eq(10)
      end

      it "credits nobody when the organization has been archived meanwhile" do
        organization.archive!

        expect { post_event }.to change { OrganizationCredit.count }.by(0)
          .and change { Credit.count }.by(0)
        expect(response).to have_http_status(:ok)
      end

      it "reverses against the pool when the dispute is lost, leaving user ledgers untouched" do
        purchase = create(
          :organization_credit,
          organization:,
          amount: 5,
          reason: "purchase",
          stripe_session_id: "cs_org_abc123",
          events: [
            {
              event_kind: "org_credit_purchased",
              event_happened_at: Time.now.utc.iso8601(3),
              event_data: { stripe_session_id: "cs_org_abc123", amount: 5 }
            }
          ]
        )

        allow(Stripe::Charge).to receive(:retrieve).and_return(
          OpenStruct.new(id: "ch_test", metadata: { "checkout_session_id" => "cs_org_abc123" })
        )

        payload = dispute_event.to_json
        headers["HTTP_STRIPE_SIGNATURE"] = sign_payload(payload)

        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.to change { OrganizationCredit.count }.by(1).and change { Credit.count }.by(0)

        reversal = OrganizationCredit.last
        expect(reversal.amount).to eq(-5)
        expect(reversal.reason).to eq("chargeback")
        expect(reversal.organization).to eq(organization)
        expect(reversal.events.first["event_data"]["original_credit_id"]).to eq(purchase.id)
        expect(organization.credit_balance).to eq(0)

        # Replaying the dispute must not reverse twice.
        expect {
          post "/webhooks/stripe", params: payload, headers: headers
        }.not_to change { OrganizationCredit.count }
      end

      def dispute_event
        Stripe::Event.construct_from(
          {
            id: "evt_dispute_lost",
            object: "event",
            type: "charge.dispute.closed",
            data: { object: { id: "dp_test", status: "lost", charge: "ch_test" } }
          }
        )
      end
    end
  end
end
