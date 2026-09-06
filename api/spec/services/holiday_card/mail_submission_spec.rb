require "rails_helper"

# Handing one charged order to PostGrid (#148). Every call here is
# webmock-stubbed; nothing reaches the network.
RSpec.describe HolidayCard::MailSubmission do
  let(:user) { create(:user, name: "Ada Lovelace") }
  let(:contact) { create(:contact, :mailable, user:, name: "Grace Hopper") }
  let(:card) { create(:holiday_card, user:) }
  let(:order) { create(:holiday_card_mail_order, user:, holiday_card: card, recipient: contact) }

  before { with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY) }

  describe "#submit!" do
    it "records the PostGrid id, the time, and the status" do
      stub_postcard_create

      freeze_time do
        expect(described_class.new(order).submit!).to be(true)

        expect(order.reload).to have_attributes(
          postgrid_id: "postcard_spec1fakepostcardid",
          # The fixture's "ready", mapped onto our vocabulary.
          status: HolidayCardMailOrder::SUBMITTED,
          submitted_at: Time.current
        )
      end
    end

    # The acceptance criterion: a retry must not print a second card, and the
    # only thing that guarantees that is the order's own stable key.
    it "sends the order's idempotency_key as the Idempotency-Key header" do
      stub = stub_postcard_create

      described_class.new(order).submit!

      expect(stub.with { |request| request.headers["Idempotency-Key"] == order.idempotency_key }).to have_been_made
    end

    # The opposite of ProofGenerator, which is hard-coded to test. A test-mode
    # send returns 2xx and mails nothing, which is the one failure with no
    # signal anywhere.
    it "authenticates with the live key, even when POSTGRID_MODE says test" do
      with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY, mode: "test")
      stub = stub_postcard_create

      described_class.new(order).submit!

      expect(stub.with { |request| request.headers["X-Api-Key"] == PostGridHelpers::LIVE_API_KEY }).to have_been_made
    end

    it "sends the rendered panels and the order's size" do
      stub = stub_postcard_create
      panels = HolidayCard::PrintRenderer.new(card).render

      described_class.new(order).submit!

      expect(stub.with { |request|
        body = JSON.parse(request.body)
        body["frontHTML"] == panels[:front] && body["backHTML"] == panels[:back] && body["size"] == order.size
      }).to have_been_made
    end

    # What was priced and what the user approved is what goes in the post — not
    # whatever the contact says today.
    it "addresses the piece from the snapshot, not from the live contact" do
      stub = stub_postcard_create
      # Ordering matters: the order — and therefore the snapshot — has to exist
      # before the contact moves under it.
      submission = described_class.new(order)
      contact.update!(name: "Someone Else", address_line1: "999 Moved Away")

      submission.submit!

      expect(stub.with { |request|
        to = JSON.parse(request.body)["to"]
        to["firstName"] == "Grace Hopper" && to["addressLine1"] == "123 Market St" && to["postalOrZip"] == "94103"
      }).to have_been_made
    end

    # A duplicate job run must not become a duplicate postcard.
    it "makes no request at all for an order that has already been submitted" do
      stub = stub_postcard_create
      order.update!(status: HolidayCardMailOrder::SUBMITTED)

      expect(described_class.new(order).submit!).to be(false)

      expect(stub).not_to have_been_made
    end

    # A success we can never look up again is not a success: without an id the
    # piece can't be traced, cancelled, or reconciled.
    it "raises a retryable ServiceError when PostGrid answers 2xx with no id" do
      stub_postcard_create(body: { "status" => "ready" }.to_json)

      expect { described_class.new(order).submit! }.to raise_error(PostGrid::ServiceError)
      expect(order.reload.status).to eq(HolidayCardMailOrder::PENDING)
    end

    it "lets a PostGrid rejection propagate for the job to decide about" do
      stub_postcard_create(body: post_grid_fixture("error_invalid_request"), status: 400)

      expect { described_class.new(order).submit! }.to raise_error(PostGrid::InvalidRequestError)
      expect(order.reload.status).to eq(HolidayCardMailOrder::PENDING)
    end
  end
end
