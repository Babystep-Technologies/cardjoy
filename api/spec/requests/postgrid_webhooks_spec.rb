require "rails_helper"

# What PostGrid tells us about a card after we mailed it (#149).
#
# The parts with teeth are all about events arriving more than once and in the
# wrong order: a replayed cancellation must not refund twice, and a late
# `printing` must not walk a delivered card backwards.
RSpec.describe "PostgridWebhooks", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:postgrid_id) { "postcard_spec1fakepostcardid" }
  let(:tracking_number) { "9400111899223197428490" }

  # A wallet with a top-up and this order's send already debited out of it, so
  # a refund shows up as a change rather than as the only row in the ledger.
  let(:debit) do
    user.spend_postage!(cents: 112, reason: "holiday_card_mail", event_kind: "postage_spent_on_mail")
  end

  before do
    with_post_grid_webhook_secret
    user.refund_postage!(cents: 500, reason: "top_up", event_kind: "postage_purchased")
  end

  let!(:order) do
    create(:holiday_card_mail_order, :submitted, user:, postgrid_id:, postage_credit: debit, charged_cents: 112)
  end

  def balance = user.reload.postage_balance_cents

  def ledger_size = user.postage_credits.count

  # The order object PostGrid puts in `data` — theirs, so camelCase and their
  # status vocabulary, not ours.
  def postcard(status:, id: postgrid_id, tracking: nil)
    { id:, object: "postcard", status:, trackingNumber: tracking }.compact
  end

  # `signature: :sign` signs the body; a string is sent verbatim; nil omits the
  # header entirely.
  def post_event(data:, type: "postcard.updated", signature: :sign, secret: PostGridHelpers::WEBHOOK_SECRET)
    payload = { type:, data: }.to_json
    headers = { "Content-Type" => "application/json" }
    header = signature == :sign ? post_grid_signature(payload, secret:) : signature
    headers["PostGrid-Signature"] = header if header

    post "/webhooks/postgrid", params: payload, headers: headers
  end

  # Delivery plus the queued work, which is where the state change lives.
  def deliver(**args)
    perform_enqueued_jobs { post_event(**args) }
  end

  describe "signature verification" do
    it "rejects a signature that does not verify, and changes nothing" do
      deliver(data: postcard(status: "cancelled"), signature: "t=1,v1=deadbeef")

      expect(response).to have_http_status(:unauthorized)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
      expect(balance).to eq(388)
    end

    it "rejects a signature made with the wrong secret" do
      deliver(data: postcard(status: "cancelled"), secret: "whsec_notoursecret")

      expect(response).to have_http_status(:unauthorized)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
    end

    it "rejects a request with no signature header at all" do
      deliver(data: postcard(status: "completed"), signature: nil)

      expect(response).to have_http_status(:unauthorized)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
    end

    it "rejects a malformed signature header" do
      deliver(data: postcard(status: "completed"), signature: "not-a-signature")

      expect(response).to have_http_status(:unauthorized)
    end

    # A box that hasn't been given the secret cannot verify anything, and this
    # endpoint issues refunds. Unverifiable means rejected, never trusted.
    it "rejects everything when no webhook secret is configured" do
      with_post_grid_webhook_secret(nil)

      deliver(data: postcard(status: "completed"))

      expect(response).to have_http_status(:unauthorized)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
    end
  end

  describe "postcard.updated" do
    it "advances the status and stores the tracking number" do
      deliver(data: postcard(status: "printing", tracking: tracking_number))

      expect(response).to have_http_status(:ok)
      expect(order.reload).to have_attributes(
        status: HolidayCardMailOrder::PRINTING,
        tracking_number: tracking_number
      )
    end

    # PostGrid re-sends the same status once a tracking number exists. The
    # status doesn't move, but the news still has to land.
    it "stores a tracking number that arrives without a status change" do
      deliver(data: postcard(status: "printing"))
      deliver(data: postcard(status: "printing", tracking: tracking_number))

      expect(order.reload).to have_attributes(
        status: HolidayCardMailOrder::PRINTING,
        tracking_number: tracking_number
      )
    end

    # Test-mode orders, proofs, and every other environment sharing the account
    # report here too. A 500 would earn us an infinite redelivery.
    it "is a no-op for an unknown postgrid_id" do
      deliver(data: postcard(status: "completed", id: "postcard_belongstosomeoneelse"))

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
      expect(ledger_size).to eq(2)
    end

    it "ignores a status we have no mapping for" do
      deliver(data: postcard(status: "entered_mail_stream"))

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
    end

    # MVP only sends postcards; the other three product events arrive on the
    # same endpoint and are not ours to interpret.
    it "ignores event types other than postcard.updated" do
      expect { post_event(type: "letter.updated", data: postcard(status: "cancelled")) }
        .not_to have_enqueued_job(PostgridWebhookJob)

      expect(response).to have_http_status(:ok)
    end

    # PostGrid retries anything it doesn't get a prompt 2xx for, so the work
    # must not be on the request's critical path.
    it "answers without doing the work inline" do
      expect { post_event(data: postcard(status: "completed")) }
        .to have_enqueued_job(PostgridWebhookJob)

      expect(response).to have_http_status(:ok)
      expect(order.reload.status).to eq(HolidayCardMailOrder::SUBMITTED)
    end
  end

  describe "replays and out-of-order delivery" do
    it "makes no second change when the same event is replayed" do
      deliver(data: postcard(status: "printing"))
      updated_at = order.reload.updated_at

      deliver(data: postcard(status: "printing"))

      expect(order.reload).to have_attributes(status: HolidayCardMailOrder::PRINTING, updated_at: updated_at)
      expect(ledger_size).to eq(2)
    end

    # The bug this whole ordering exists to prevent: a delivered card that says
    # it is still at the printer.
    it "ignores an event that would move the status backwards" do
      deliver(data: postcard(status: "completed"))
      deliver(data: postcard(status: "printing"))

      expect(order.reload.status).to eq(HolidayCardMailOrder::COMPLETED)
    end

    it "ignores a `ready` event arriving after the order has moved on" do
      deliver(data: postcard(status: "printing"))
      deliver(data: postcard(status: "ready"))

      expect(order.reload.status).to eq(HolidayCardMailOrder::PRINTING)
    end
  end

  describe "mailed_at" do
    it "is set on the first transition into processed_for_delivery" do
      expect(order.mailed_at).to be_nil

      deliver(data: postcard(status: "processed_for_delivery"))

      expect(order.reload.mailed_at).to be_present
    end

    it "is not moved by later events" do
      deliver(data: postcard(status: "processed_for_delivery"))
      mailed_at = order.reload.mailed_at

      deliver(data: postcard(status: "processed_for_delivery"))
      deliver(data: postcard(status: "completed"))

      expect(order.reload).to have_attributes(status: HolidayCardMailOrder::COMPLETED, mailed_at: mailed_at)
    end
  end

  describe "refunds" do
    it "refunds exactly charged_cents when PostGrid cancels the order" do
      deliver(data: postcard(status: "cancelled"))

      expect(order.reload.status).to eq(HolidayCardMailOrder::CANCELLED)
      expect(balance).to eq(388 + 112)

      refund = user.postage_credits.order(:id).last
      expect(refund).to have_attributes(amount_cents: 112, reason: "holiday_card_mail_refund")
      expect(refund.events.first["event_kind"]).to eq("postage_refunded")
      expect(refund.events.first["event_data"]).to include("holiday_card_mail_order_id" => order.id)
    end

    it "refunds on a failure event too" do
      deliver(data: postcard(status: "failed"))

      expect(order.reload.status).to eq(HolidayCardMailOrder::FAILED)
      expect(balance).to eq(388 + 112)
    end

    # The acceptance criterion with the most money attached. The guard is the
    # conditional UPDATE on `status`: the replay claims no row, so it never
    # reaches the refund.
    it "does not refund twice when the cancellation is replayed" do
      deliver(data: postcard(status: "cancelled"))

      deliver(data: postcard(status: "cancelled"))

      expect(balance).to eq(388 + 112)
      expect(ledger_size).to eq(3)
    end

    # A cancellation that arrives after the carrier delivered the card is not a
    # reason to hand the money back for a card that was really mailed.
    it "does not refund a card that already completed" do
      deliver(data: postcard(status: "completed"))

      deliver(data: postcard(status: "cancelled"))

      expect(order.reload.status).to eq(HolidayCardMailOrder::COMPLETED)
      expect(balance).to eq(388)
      expect(ledger_size).to eq(2)
    end

    # No debit row behind the order means nothing was ever taken for it, and a
    # refund would mint postage out of nothing.
    it "does not write a refund row for an order that was never charged" do
      uncharged = create(
        :holiday_card_mail_order, :submitted,
        user:, postgrid_id: "postcard_neverchargedspec", postage_credit: nil
      )

      deliver(data: postcard(status: "cancelled", id: uncharged.postgrid_id))

      expect(uncharged.reload.status).to eq(HolidayCardMailOrder::CANCELLED)
      expect(balance).to eq(388)
      expect(ledger_size).to eq(2)
    end
  end
end
