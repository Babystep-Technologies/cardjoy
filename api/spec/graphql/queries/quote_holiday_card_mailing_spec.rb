require "rails_helper"

# The mailing quote (#147): a per-recipient breakdown, a total over only the
# mailable recipients, and the caller's wallet balance beside it.
#
# Every PostGrid call here is webmock-stubbed; nothing reaches the network.
RSpec.describe "quoteHolidayCardMailing", type: :request do
  let(:user) { create(:user) }
  let(:card) { create(:holiday_card, user:, size: "6x4") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  # The 6x4 domestic price: 86¢ cost, 30% markup, rounded up.
  let(:us_total_cents) { 112 }

  let(:query) do
    <<~GRAPHQL
      query QuoteHolidayCardMailing($holidayCardId: ID!, $contactIds: [ID!]!) {
        quoteHolidayCardMailing(holidayCardId: $holidayCardId, contactIds: $contactIds) {
          totalCents
          mailableCount
          unmailableCount
          postageBalanceCents
          entries {
            contact { id name }
            mailable
            addressVerificationStatus
            zone
            totalCents
            reason
          }
        }
      }
    GRAPHQL
  end

  def exec(contact_ids:, holiday_card_id: card.external_id, request_headers: headers)
    body = {
      query:,
      variables: { holidayCardId: holiday_card_id, contactIds: contact_ids.map(&:to_s) }
    }
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  def quote_for(**) = exec(**).dig("data", "quoteHolidayCardMailing")

  def error_messages(result) = result.fetch("errors", []).map { |e| e["message"] }

  describe "a priced quote" do
    it "prices each verified recipient and totals them" do
      contacts = create_list(:contact, 3, :address_verified, user:)

      quote = quote_for(contact_ids: contacts.map(&:id))

      expect(quote["mailableCount"]).to eq(3)
      expect(quote["unmailableCount"]).to eq(0)
      expect(quote["totalCents"]).to eq(us_total_cents * 3)
      expect(quote["entries"].map { |e| e["totalCents"] }).to all(eq(us_total_cents))
      expect(quote["entries"].map { |e| e["reason"] }).to all(be_nil)
    end

    it "prices by destination zone, not by a single flat rate" do
      us = create(:contact, :address_verified, user:, name: "Ada")
      canada = create(:contact, :address_verified, user:, name: "Bea", zone: "canada")
      abroad = create(:contact, :address_verified, user:, name: "Cyd", zone: "international")

      entries = quote_for(contact_ids: [ us.id, canada.id, abroad.id ])["entries"]

      expect(entries.map { |e| e["zone"] }).to eq(%w[us_domestic canada international])
      expect(entries.map { |e| e["totalCents"] }).to eq([ 112, 189, 254 ])
    end

    it "prices by the card's size" do
      contact = create(:contact, :address_verified, user:)
      large = create(:holiday_card, user:, size: "6x9")

      quote = quote_for(contact_ids: [ contact.id ], holiday_card_id: large.external_id)

      # 98¢ × 1.30 = 127.4, rounded up.
      expect(quote["totalCents"]).to eq(128)
    end

    it "returns one entry per contact, in the order asked for" do
      first = create(:contact, :address_verified, user:, name: "Zoe")
      second = create(:contact, :address_verified, user:, name: "Abe")

      entries = quote_for(contact_ids: [ first.id, second.id ])["entries"]

      expect(entries.map { |e| e.dig("contact", "name") }).to eq(%w[Zoe Abe])
    end

    it "collapses a duplicated contact id into one entry" do
      contact = create(:contact, :address_verified, user:)

      quote = quote_for(contact_ids: [ contact.id, contact.id ])

      expect(quote["entries"].size).to eq(1)
      expect(quote["totalCents"]).to eq(us_total_cents)
    end

    it "reports the caller's postage balance so the client can show the shortfall" do
      create(:postage_credit, user:, amount_cents: 500)
      contacts = create_list(:contact, 3, :address_verified, user:)

      quote = quote_for(contact_ids: contacts.map(&:id))

      expect(quote["postageBalanceCents"]).to eq(500)
      expect(quote["totalCents"]).to eq(336)
    end
  end

  describe "recipients that cannot be mailed" do
    it "flags a contact with no address, with a reason and no price" do
      contact = create(:contact, user:, name: "No Address")

      quote = quote_for(contact_ids: [ contact.id ])
      entry = quote["entries"].first

      expect(entry["mailable"]).to be(false)
      expect(entry["totalCents"]).to be_nil
      expect(entry["reason"]).to eq(HolidayCard::MailingQuote::MISSING_ADDRESS_REASON)
      expect(quote["unmailableCount"]).to eq(1)
      expect(quote["totalCents"]).to eq(0)
    end

    it "flags an undeliverable address rather than pricing it" do
      contact = create(:contact, :address_verified, user:, verification_status: Contact::UNDELIVERABLE_STATUS)

      entry = quote_for(contact_ids: [ contact.id ])["entries"].first

      expect(entry["addressVerificationStatus"]).to eq("undeliverable")
      expect(entry["totalCents"]).to be_nil
      expect(entry["reason"]).to eq(HolidayCard::MailingQuote::UNDELIVERABLE_REASON)
    end

    # The case a domestic-rate fallback would have quietly mispriced.
    it "flags a verified address in a zone the rate card does not cover" do
      contact = create(:contact, :address_verified, user:, zone: "antarctica")

      entry = quote_for(contact_ids: [ contact.id ])["entries"].first

      expect(entry["zone"]).to eq("antarctica")
      expect(entry["totalCents"]).to be_nil
      expect(entry["reason"]).to eq(HolidayCard::MailingQuote::UNSUPPORTED_DESTINATION_REASON)
    end

    it "keeps flagged recipients in the list rather than dropping them" do
      mailable = create(:contact, :address_verified, user:, name: "Ada")
      no_address = create(:contact, user:, name: "Bea")
      undeliverable = create(:contact, :address_verified, user:, name: "Cyd",
        verification_status: Contact::UNDELIVERABLE_STATUS)

      quote = quote_for(contact_ids: [ mailable.id, no_address.id, undeliverable.id ])

      expect(quote["entries"].map { |e| e.dig("contact", "name") }).to eq(%w[Ada Bea Cyd])
      expect(quote["mailableCount"]).to eq(1)
      expect(quote["unmailableCount"]).to eq(2)
      expect(quote["totalCents"]).to eq(us_total_cents)
    end

    it "returns a zero total for a list with nobody mailable, without raising" do
      contacts = create_list(:contact, 2, user:)

      quote = quote_for(contact_ids: contacts.map(&:id))

      expect(quote["totalCents"]).to eq(0)
      expect(quote["mailableCount"]).to eq(0)
      expect(quote["unmailableCount"]).to eq(2)
    end

    it "returns a zero total for an empty recipient list" do
      quote = quote_for(contact_ids: [])

      expect(quote["entries"]).to eq([])
      expect(quote["totalCents"]).to eq(0)
      expect(quote["mailableCount"]).to eq(0)
    end
  end

  describe "verifying unverified addresses as part of quoting" do
    let(:contact) { create(:contact, :mailable, user:) }

    before { with_post_grid_key }

    it "verifies an unverified contact and caches the verdict" do
      stub = stub_verification(body: post_grid_fixture("verification_us_deliverable"))

      entry = quote_for(contact_ids: [ contact.id ])["entries"].first

      expect(stub).to have_been_requested
      expect(entry["addressVerificationStatus"]).to eq("verified")
      expect(entry["zone"]).to eq("us_domestic")
      expect(entry["totalCents"]).to eq(us_total_cents)

      expect(contact.reload.address_verification_status).to eq("verified")
      expect(contact.address_zone).to eq("us_domestic")
      expect(contact.address_verified_at).to be_present
    end

    it "prices an address PostGrid resolves to Canada at the Canadian rate" do
      stub_verification(body: post_grid_fixture("verification_ca_deliverable"))

      entry = quote_for(contact_ids: [ contact.id ])["entries"].first

      expect(entry["zone"]).to eq("canada")
      expect(entry["totalCents"]).to eq(189)
    end

    it "flags an address PostGrid says is undeliverable, and caches that too" do
      stub_verification(body: post_grid_fixture("verification_us_undeliverable"))

      entry = quote_for(contact_ids: [ contact.id ])["entries"].first

      expect(entry["totalCents"]).to be_nil
      expect(entry["reason"]).to eq(HolidayCard::MailingQuote::UNDELIVERABLE_REASON)
      expect(contact.reload.address_verification_status).to eq("undeliverable")
    end

    it "does not re-verify a contact that already has a cached verdict" do
      stub = stub_verification(body: post_grid_fixture("verification_us_deliverable"))
      verified = create(:contact, :address_verified, user:)

      quote_for(contact_ids: [ verified.id ])

      expect(stub).not_to have_been_requested
    end

    it "does not re-verify on a second quote of the same list" do
      stub = stub_verification(body: post_grid_fixture("verification_us_deliverable"))

      2.times { quote_for(contact_ids: [ contact.id ]) }

      expect(stub).to have_been_requested.once
    end

    # One unreachable address must not cost the user the other prices.
    it "flags a contact whose verification fails, and still prices the rest" do
      stub_request(:post, PostGridHelpers::VERIFY_URL).to_return(
        status: 500, body: post_grid_fixture("error_server"), headers: { "Content-Type" => "application/json" }
      )
      priced = create(:contact, :address_verified, user:, name: "Ada")

      quote = quote_for(contact_ids: [ priced.id, contact.id ])

      expect(quote["entries"].last["reason"]).to eq(HolidayCard::MailingQuote::VERIFICATION_UNAVAILABLE_REASON)
      expect(quote["entries"].last["totalCents"]).to be_nil
      expect(quote["totalCents"]).to eq(us_total_cents)
      expect(quote["mailableCount"]).to eq(1)
    end
  end

  describe "when PostGrid is not configured" do
    # The normal state of a fresh clone and of CI. Nothing may crash.
    it "flags an unverified contact instead of raising" do
      contact = create(:contact, :mailable, user:)

      entry = quote_for(contact_ids: [ contact.id ])["entries"].first

      expect(entry["reason"]).to eq(HolidayCard::MailingQuote::VERIFICATION_UNAVAILABLE_REASON)
      expect(entry["totalCents"]).to be_nil
    end

    it "still prices contacts that were verified earlier" do
      contact = create(:contact, :address_verified, user:)

      expect(quote_for(contact_ids: [ contact.id ])["totalCents"]).to eq(us_total_cents)
    end
  end

  describe "what the quote does not expose" do
    it "has no field for the base cost or the markup" do
      quote_type = ApiSchema.types["HolidayCardMailingQuote"]
      entry_type = ApiSchema.types["HolidayCardMailingQuoteEntry"]

      names = quote_type.fields.keys + entry_type.fields.keys

      expect(names).not_to include("baseCents", "markupCents", "markupMultiplier", "markupBasisPoints")
    end

    it "rejects a query that asks for baseCents" do
      contact = create(:contact, :address_verified, user:)
      post "/graphql",
        params: {
          query: "query Q($c: [ID!]!) { quoteHolidayCardMailing(holidayCardId: \"#{card.external_id}\", " \
                 "contactIds: $c) { entries { baseCents } } }",
          variables: { c: [ contact.id.to_s ] }
        }.to_json,
        headers: headers

      expect(error_messages(JSON.parse(response.body)).join).to match(/baseCents/)
    end
  end

  describe "authorization" do
    it "rejects an unauthenticated caller at the controller" do
      exec(contact_ids: [], request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
    end

    # PUBLIC_OPERATIONS matches on the operation *name*, so the resolver has to
    # answer for itself.
    it "returns Not authenticated for a caller smuggled into a public operation name" do
      smuggled = <<~GRAPHQL
        query Card {
          quoteHolidayCardMailing(holidayCardId: "#{card.external_id}", contactIds: []) { totalCents }
        }
      GRAPHQL
      post "/graphql",
        params: { query: smuggled, operationName: "Card" }.to_json,
        headers: anonymous_headers

      expect(error_messages(JSON.parse(response.body))).to include("Not authenticated")
    end

    it "returns Not authorized for another user's card" do
      contact = create(:contact, :address_verified, user:)
      stranger_card = create(:holiday_card)

      result = exec(contact_ids: [ contact.id ], holiday_card_id: stranger_card.external_id)

      expect(error_messages(result)).to include("Not authorized")
    end

    it "returns Not authorized for a card that does not exist" do
      result = exec(contact_ids: [], holiday_card_id: "ZZZZZZZ")

      expect(error_messages(result)).to include("Not authorized")
    end

    it "returns Not authorized for another user's contact" do
      stranger_contact = create(:contact, :address_verified)

      result = exec(contact_ids: [ stranger_contact.id ])

      expect(error_messages(result)).to include("Not authorized")
    end

    it "denies the whole quote when only one id belongs to someone else" do
      mine = create(:contact, :address_verified, user:)
      theirs = create(:contact, :address_verified)

      result = exec(contact_ids: [ mine.id, theirs.id ])

      expect(error_messages(result)).to include("Not authorized")
      expect(result.dig("data", "quoteHolidayCardMailing")).to be_nil
    end

    it "returns Not authorized for a contact id that does not exist" do
      result = exec(contact_ids: [ 0 ])

      expect(error_messages(result)).to include("Not authorized")
    end

    it "refuses an unbounded recipient list" do
      ids = Array.new(Queries::QuoteHolidayCardMailing::MAX_CONTACTS + 1) { |n| n + 1 }

      result = exec(contact_ids: ids)

      expect(error_messages(result)).to include(Queries::QuoteHolidayCardMailing::TOO_MANY_CONTACTS_ERROR)
    end
  end
end
