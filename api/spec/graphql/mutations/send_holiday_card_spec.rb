require "rails_helper"

# Sending a holiday card to physical addresses (#148) — the point where money
# and an irreversible physical action meet.
#
# Every PostGrid call here is webmock-stubbed; nothing reaches the network.
RSpec.describe Mutations::SendHolidayCard, type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:stranger) { create(:user) }
  let(:card) { create(:holiday_card, user:, size: "6x4") }
  let(:ada) { create(:contact, :address_verified, user:, name: "Ada Lovelace") }
  let(:grace) { create(:contact, :address_verified, user:, name: "Grace Hopper") }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  # The 6x4 domestic price: 86¢ cost, 30% markup, rounded up.
  let(:piece_cents) { 112 }

  let(:query) do
    <<~GRAPHQL
      mutation SendHolidayCard($holidayCardId: ID!, $contactIds: [ID!]!, $mailingClass: String) {
        sendHolidayCard(input: {
          holidayCardId: $holidayCardId, contactIds: $contactIds, mailingClass: $mailingClass
        }) {
          orders {
            id
            status
            chargedCents
            recipientName
            recipientAddress { addressLine1 city postalCode countryCode }
            failureReason
          }
          totalChargedCents
          errors
        }
      }
    GRAPHQL
  end

  before { with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY) }

  # What ProofGenerator and approveHolidayCardProof leave behind, written
  # directly so this spec never renders or submits a proof.
  def approve_proof(on: card, generated_at: Time.current)
    on.update!(
      proof_url: "https://example.test/proof.pdf",
      proof_generated_at: generated_at,
      proof_design_digest: on.proof_design_digest_for_current_design
    )
    on.update!(proof_approved_at: Time.current)
    on
  end

  def top_up(cents)
    user.refund_postage!(cents:, reason: "top_up", event_kind: "postage_purchased")
  end

  def exec(contacts:, holiday_card_id: card.external_id, mailing_class: nil, request_headers: headers)
    body = {
      query:,
      variables: {
        holidayCardId: holiday_card_id,
        contactIds: Array(contacts).map { |contact| contact.respond_to?(:id) ? contact.id.to_s : contact.to_s },
        mailingClass: mailing_class
      }
    }
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body).dig("data", "sendHolidayCard")
  end

  def balance = user.reload.postage_balance_cents

  describe "a successful send" do
    before do
      approve_proof
      top_up(1_000)
    end

    it "creates one pending order per recipient and charges each one separately" do
      result = exec(contacts: [ ada, grace ])

      expect(result["errors"]).to be_empty
      expect(result["totalChargedCents"]).to eq(piece_cents * 2)
      expect(result["orders"].map { |order| order["status"] }).to eq([ "pending", "pending" ])
      expect(result["orders"].map { |order| order["chargedCents"] }).to eq([ piece_cents, piece_cents ])
      expect(result["orders"].map { |order| order["recipientName"] }).to contain_exactly("Ada Lovelace", "Grace Hopper")

      expect(HolidayCardMailOrder.count).to eq(2)
      expect(balance).to eq(1_000 - (piece_cents * 2))
    end

    # One debit per piece, not one for the batch: a single failed card then
    # refunds exactly its own cents with no arithmetic.
    it "writes one negative postage_credits row per order, linked to it" do
      exec(contacts: [ ada, grace ])

      debits = user.postage_credits.where(reason: "holiday_card_mail")
      expect(debits.pluck(:amount_cents)).to eq([ -piece_cents, -piece_cents ])
      expect(HolidayCardMailOrder.pluck(:postage_credit_id)).to match_array(debits.ids)
    end

    it "gives every order its own idempotency key" do
      exec(contacts: [ ada, grace ])

      keys = HolidayCardMailOrder.pluck(:idempotency_key)
      expect(keys.uniq.size).to eq(2)
      expect(keys).to all(be_present)
    end

    it "snapshots the address at send time" do
      result = exec(contacts: [ ada ])

      expect(result["orders"].first["recipientAddress"]).to eq(
        "addressLine1" => "123 Market St", "city" => "San Francisco",
        "postalCode" => "94103", "countryCode" => "US"
      )
    end

    it "records what it priced against, without exposing it" do
      exec(contacts: [ ada ])

      expect(HolidayCardMailOrder.last).to have_attributes(
        size: "6x4",
        mailing_class: MailPricing::MAILING_CLASS_FIRST_CLASS,
        zone: PostGrid::AddressVerification::ZONE_US_DOMESTIC,
        rate_card_version: MailPricing::CURRENT_RATE_CARD_VERSION,
        base_cents: 86,
        charged_cents: piece_cents
      )
    end

    it "collapses duplicate contact ids so nobody is charged twice for one send" do
      result = exec(contacts: [ ada, ada ])

      expect(result["orders"].size).to eq(1)
      expect(balance).to eq(1_000 - piece_cents)
    end

    it "enqueues one submission job per order" do
      expect { exec(contacts: [ ada, grace ]) }
        .to have_enqueued_job(HolidayCardMailSubmissionJob).exactly(2).times
    end
  end

  describe "keeping PostGrid out of the transaction" do
    before do
      approve_proof
      top_up(1_000)
    end

    # An external call inside the debit transaction holds a connection open for
    # a network round trip and, worse, cannot be rolled back.
    it "submits nothing to PostGrid while the mutation runs" do
      stub = stub_postcard_create

      exec(contacts: [ ada, grace ])

      expect(stub).not_to have_been_made
    end

    # The sharper version of the same claim: when the call finally happens, the
    # transaction that took the money is already closed.
    it "has closed the transaction by the time PostGrid is called" do
      baseline = ActiveRecord::Base.connection.open_transactions
      depth_at_call = nil
      stub_request(:post, PostGridHelpers::POSTCARDS_URL).to_return do
        depth_at_call = ActiveRecord::Base.connection.open_transactions
        { status: 200, body: post_grid_fixture("postcard_test_created"),
          headers: { "Content-Type" => "application/json" } }
      end

      perform_enqueued_jobs { exec(contacts: [ ada ]) }

      expect(depth_at_call).to eq(baseline)
      expect(HolidayCardMailOrder.last.status).to eq(HolidayCardMailOrder::SUBMITTED)
    end
  end

  describe "the proof gate" do
    before { top_up(1_000) }

    it "refuses a card whose proof has never been approved, and debits nothing" do
      result = exec(contacts: [ ada ])

      expect(result["errors"]).to eq([ described_class::NO_PROOF_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end

    # The bug the whole proof mechanism exists to prevent: what the user
    # approved has to be what prints.
    it "refuses a card edited since its proof was approved, and debits nothing" do
      approve_proof
      # Written past the approval-clearing callback, so the only thing standing
      # between this send and the printer is `proof_current?`.
      card.update_columns(template_id: "snowy_trio_alt")

      result = exec(contacts: [ ada ])

      expect(result["errors"]).to eq([ described_class::STALE_PROOF_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end

    it "refuses a proof that has aged past PROOF_MAX_AGE, and debits nothing" do
      approve_proof(generated_at: (HolidayCard::PROOF_MAX_AGE + 1.hour).ago)

      result = exec(contacts: [ ada ])

      expect(result["errors"]).to eq([ described_class::STALE_PROOF_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end
  end

  describe "recipient and ownership checks" do
    before do
      approve_proof
      top_up(1_000)
    end

    it "refuses a contact with no complete address, naming them, and debits nothing" do
      no_address = create(:contact, user:, name: "Charles Babbage")

      result = exec(contacts: [ ada, no_address ])

      expect(result["errors"]).to eq(
        [ "Charles Babbage: #{HolidayCard::MailingQuote::MISSING_ADDRESS_REASON}" ]
      )
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end

    it "refuses an address PostGrid says is undeliverable, and debits nothing" do
      bad = create(:contact, :address_verified, user:, name: "Nobody",
        verification_status: Contact::UNDELIVERABLE_STATUS)

      result = exec(contacts: [ bad ])

      expect(result["errors"]).to eq([ "Nobody: #{HolidayCard::MailingQuote::UNDELIVERABLE_REASON}" ])
      expect(balance).to eq(1_000)
    end

    it "refuses somebody else's contact, and debits nothing" do
      result = exec(contacts: [ ada, create(:contact, :address_verified, user: stranger) ])

      expect(result["errors"]).to eq([ described_class::NOT_AUTHORIZED_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end

    it "refuses a contact that doesn't exist, and debits nothing" do
      result = exec(contacts: [ ada.id, 999_999 ])

      expect(result["errors"]).to eq([ described_class::NOT_AUTHORIZED_ERROR ])
      expect(balance).to eq(1_000)
    end

    # Somebody else's card and a card that doesn't exist give the same answer,
    # so a stranger can't probe which externalIds are real.
    it "refuses somebody else's card, and debits nothing" do
      result = exec(contacts: [ ada ], holiday_card_id: create(:holiday_card, user: stranger).external_id)

      expect(result["errors"]).to eq([ described_class::NOT_AUTHORIZED_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end

    it "gives the same answer for a card that doesn't exist" do
      expect(exec(contacts: [ ada ], holiday_card_id: "ZZZZZZZ")["errors"])
        .to eq([ described_class::NOT_AUTHORIZED_ERROR ])
    end

    it "refuses an empty recipient list" do
      expect(exec(contacts: [])["errors"]).to eq([ described_class::NO_RECIPIENTS_ERROR ])
    end

    it "rejects an anonymous caller at the controller" do
      exec(contacts: [ ada ], request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(HolidayCardMailOrder.count).to eq(0)
    end

    # The mutation's own backstop, for a caller smuggled in under a name
    # GraphqlController::PUBLIC_OPERATIONS treats as public.
    it "returns Not authenticated for a caller smuggled in under a public operation name" do
      smuggled = <<~GRAPHQL
        mutation Card($holidayCardId: ID!, $contactIds: [ID!]!) {
          sendHolidayCard(input: { holidayCardId: $holidayCardId, contactIds: $contactIds }) { errors }
        }
      GRAPHQL

      post "/graphql",
        params: { query: smuggled, operationName: "Card",
                  variables: { holidayCardId: card.external_id, contactIds: [ ada.id.to_s ] } }.to_json,
        headers: anonymous_headers
      result = JSON.parse(response.body).dig("data", "sendHolidayCard")

      expect(result["errors"]).to eq([ described_class::NOT_AUTHENTICATED_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
    end
  end

  describe "the wallet" do
    before { approve_proof }

    it "rolls back completely and names the shortfall in cents" do
      top_up(150)

      result = exec(contacts: [ ada, grace ])

      expect(result["errors"].first).to eq(
        "Not enough postage. This send costs 224 cents and your wallet has 150 cents — you're 74 cents short."
      )
      expect(result["orders"]).to be_nil
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(user.postage_credits.where(reason: "holiday_card_mail")).to be_empty
      expect(balance).to eq(150)
    end

    it "rejects a send from an empty wallet without writing anything" do
      result = exec(contacts: [ ada ])

      expect(result["errors"].first).to include("112 cents", "0 cents", "112 cents short")
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(0)
    end

    it "allows a send that spends the wallet down to exactly zero" do
      top_up(piece_cents)

      expect(exec(contacts: [ ada ])["errors"]).to be_empty
      expect(balance).to eq(0)
    end
  end

  describe "server-side pricing" do
    before do
      approve_proof
      top_up(1_000)
    end

    # The strongest form of "the client's number is ignored": there is no
    # argument that could carry one.
    it "accepts no argument that could carry a price" do
      input_type = ApiSchema.mutation.fields["sendHolidayCard"].arguments["input"].type.unwrap

      expect(input_type.arguments.keys)
        .to contain_exactly("holidayCardId", "contactIds", "mailingClass", "clientMutationId")
    end

    it "prices from the destination zone, not from a default" do
      canadian = create(:contact, :address_verified, user:, name: "Alice",
        zone: PostGrid::AddressVerification::ZONE_CANADA)

      result = exec(contacts: [ canadian ])

      # 145¢ cost, 30% markup, rounded up.
      expect(result["orders"].first["chargedCents"]).to eq(189)
    end

    it "refuses a mailing class we don't offer" do
      expect(exec(contacts: [ ada ], mailing_class: "carrier_pigeon")["errors"])
        .to eq([ described_class::UNKNOWN_MAILING_CLASS_ERROR ])
      expect(balance).to eq(1_000)
    end
  end

  describe "when PostGrid has no live key" do
    before do
      approve_proof
      top_up(1_000)
      with_post_grid_key(live_key: nil)
    end

    # Nothing here could ever be printed, so it refuses up front rather than
    # taking the money and queueing work that must fail.
    it "refuses the send and debits nothing" do
      result = exec(contacts: [ ada ])

      expect(result["errors"]).to eq([ described_class::UNAVAILABLE_ERROR ])
      expect(HolidayCardMailOrder.count).to eq(0)
      expect(balance).to eq(1_000)
    end
  end

  describe "partial batch failure" do
    before do
      approve_proof
      top_up(1_000)
    end

    # Because each order is independent, one rejection refunds one piece and
    # leaves the rest in the post. This is the normal case, not an exception.
    it "fails and refunds one piece while the others go out" do
      stub_const("PostGrid::Client::MAX_ATTEMPTS", 1)
      stub_request(:post, PostGridHelpers::POSTCARDS_URL)
        .to_return(status: 400, body: post_grid_fixture("error_invalid_request"),
          headers: { "Content-Type" => "application/json" })
        .then
        .to_return(status: 200, body: post_grid_fixture("postcard_test_created"),
          headers: { "Content-Type" => "application/json" })

      perform_enqueued_jobs { exec(contacts: [ ada, grace ]) }

      statuses = HolidayCardMailOrder.order(:id).pluck(:status)
      expect(statuses).to contain_exactly(HolidayCardMailOrder::FAILED, HolidayCardMailOrder::SUBMITTED)

      failed = HolidayCardMailOrder.find_by(status: HolidayCardMailOrder::FAILED)
      expect(failed.failure_reason).to be_present
      # Exactly one piece back: 1000 - 224 charged + 112 refunded.
      expect(balance).to eq(1_000 - 224 + piece_cents)
      expect(HolidayCardMailOrder.find_by(status: HolidayCardMailOrder::SUBMITTED).postgrid_id).to be_present
    end
  end
end
