require "rails_helper"

# The job that turns a charged order into a printed card, and the three ways it
# can end (#148). Every PostGrid call is webmock-stubbed.
RSpec.describe HolidayCardMailSubmissionJob do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:contact) { create(:contact, :mailable, user:) }
  let(:card) { create(:holiday_card, user:) }
  let(:order) { create(:holiday_card_mail_order, user:, holiday_card: card, recipient: contact, charged_cents: 112) }

  before do
    with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY)
    # A wallet with the send already debited out of it, so a refund is visible
    # as a change rather than as the only row in the ledger.
    user.refund_postage!(cents: 500, reason: "top_up", event_kind: "postage_purchased")
    user.spend_postage!(cents: 112, reason: "holiday_card_mail", event_kind: "postage_spent_on_mail")
  end

  def balance = user.reload.postage_balance_cents

  describe "success" do
    it "submits the order and leaves the wallet alone" do
      stub_postcard_create

      described_class.perform_now(order.id)

      expect(order.reload).to have_attributes(
        status: HolidayCardMailOrder::SUBMITTED,
        postgrid_id: "postcard_spec1fakepostcardid"
      )
      expect(balance).to eq(388)
    end
  end

  describe "a retryable PostGrid failure" do
    # Collapses the client's own three attempts into one so this spec exercises
    # the *job's* retry policy, and doesn't spend its time in the client's
    # backoff sleeps.
    before { stub_const("PostGrid::Client::MAX_ATTEMPTS", 1) }

    # The wallet is untouched and the order stays pending: PostGrid being down
    # is not the user's problem and not a reason to unwind their send.
    it "leaves the order pending, re-enqueues, and refunds nothing" do
      stub_postcard_create(body: post_grid_fixture("error_server"), status: 503)

      expect { described_class.perform_now(order.id) }.to have_enqueued_job(described_class).with(order.id)

      expect(order.reload.status).to eq(HolidayCardMailOrder::PENDING)
      expect(order.failure_reason).to be_nil
      expect(balance).to eq(388)
    end

    # The retry replays the same order, so it replays the same key — which is
    # what stops PostGrid printing a second card if the first request actually
    # landed.
    it "reuses the order's idempotency_key across attempts" do
      stub = stub_postcard_create(body: post_grid_fixture("error_server"), status: 503)

      perform_enqueued_jobs { described_class.perform_later(order.id) }

      expect(stub.with { |request| request.headers["Idempotency-Key"] == order.idempotency_key })
        .to have_been_made.times(described_class::MAX_ATTEMPTS)
    end
  end

  describe "a 4xx from PostGrid" do
    before { stub_postcard_create(body: post_grid_fixture("error_invalid_request"), status: 400) }

    it "fails the order, records the reason, and refunds exactly charged_cents" do
      described_class.perform_now(order.id)

      expect(order.reload.status).to eq(HolidayCardMailOrder::FAILED)
      expect(order.failure_reason).to start_with("Our print partner couldn't accept this card:")
      expect(balance).to eq(500)
    end

    it "does not retry — a replayed 4xx just fails again" do
      expect { described_class.perform_now(order.id) }.not_to have_enqueued_job(described_class)
    end

    # The acceptance criterion: two runs of the same job neither double-submit
    # nor double-refund.
    it "refunds once when the job runs twice" do
      described_class.perform_now(order.id)
      described_class.perform_now(order.id)

      expect(balance).to eq(500)
      expect(user.postage_credits.where(reason: "holiday_card_mail_refund").count).to eq(1)
    end
  end

  describe "a card whose template has been retired" do
    it "fails the order and refunds, without ever calling PostGrid" do
      stub = stub_postcard_create
      allow(HolidayCard::PrintRenderer).to receive(:new)
        .and_raise(HolidayCard::PrintRenderer::UnknownTemplateError)

      described_class.perform_now(order.id)

      expect(stub).not_to have_been_made
      expect(order.reload.status).to eq(HolidayCardMailOrder::FAILED)
      expect(order.failure_reason).to eq(described_class::TEMPLATE_RETIRED_REASON)
      expect(balance).to eq(500)
    end
  end

  describe "our own misconfiguration" do
    # Our fault, not the order's — but holding the user's money against a config
    # error we might not notice for a day is not a defensible default.
    it "fails and refunds on an authentication error, without leaking which key" do
      stub_postcard_create(body: post_grid_fixture("error_unauthorized"), status: 401)

      described_class.perform_now(order.id)

      expect(order.reload.status).to eq(HolidayCardMailOrder::FAILED)
      expect(order.failure_reason).to eq(described_class::UNAVAILABLE_REASON)
      expect(balance).to eq(500)
    end
  end

  describe "an order that is no longer pending" do
    it "makes no request for an order that already succeeded" do
      stub = stub_postcard_create
      order.update!(status: HolidayCardMailOrder::SUBMITTED)

      described_class.perform_now(order.id)

      expect(stub).not_to have_been_made
    end

    # Deserialized by id rather than GlobalID precisely so this is a no-op
    # instead of a DeserializationError on every attempt.
    it "does nothing for an order that has been deleted" do
      stub = stub_postcard_create
      id = order.id
      order.destroy!

      expect { described_class.perform_now(id) }.not_to raise_error
      expect(stub).not_to have_been_made
    end
  end

  describe "retries exhausted" do
    before { stub_const("PostGrid::Client::MAX_ATTEMPTS", 1) }

    it "takes the same terminal path as a 4xx: failed, with a refund" do
      stub_postcard_create(body: post_grid_fixture("error_server"), status: 503)

      perform_enqueued_jobs { described_class.perform_later(order.id) }

      expect(order.reload.status).to eq(HolidayCardMailOrder::FAILED)
      expect(order.failure_reason).to eq(described_class::UNAVAILABLE_REASON)
      expect(balance).to eq(500)
    end
  end
end
