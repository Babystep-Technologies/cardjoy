require "rails_helper"

RSpec.describe "Holiday card queries", type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  def exec(query, variables: {}, request_headers: headers, operation_name: nil)
    body = { query:, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  describe "myHolidayCards" do
    let(:query) do
      <<~GRAPHQL
        query MyHolidayCards {
          myHolidayCards { id externalId title size templateId designConfig createdAt updatedAt }
        }
      GRAPHQL
    end

    it "returns only the caller's cards, newest first" do
      create(:holiday_card, user:, title: "Older", created_at: 2.days.ago)
      create(:holiday_card, user:, title: "Newer", created_at: 1.hour.ago)
      create(:holiday_card, title: "Someone else's")

      result = exec(query).dig("data", "myHolidayCards")

      expect(result.map { |c| c["title"] }).to eq([ "Newer", "Older" ])
    end

    it "omits a soft-deleted card" do
      create(:holiday_card, user:, title: "Kept")
      create(:holiday_card, user:, title: "Gone").delete!

      result = exec(query).dig("data", "myHolidayCards")

      expect(result.map { |c| c["title"] }).to eq([ "Kept" ])
    end

    it "rejects an unauthenticated caller at the controller" do
      exec(query, request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    end

    # PUBLIC_OPERATIONS is matched against the operation *name*, so a caller can
    # skip the controller gate by naming their operation "Card". The resolver
    # has to answer for itself.
    it "rejects an unauthenticated caller smuggled into a public operation name" do
      smuggled = "query Card { myHolidayCards { id } }"
      result = exec(smuggled, request_headers: anonymous_headers, operation_name: "Card")

      expect(result["errors"].map { |e| e["message"] }).to include("Not authenticated")
      expect(result.dig("data", "myHolidayCards")).to be_nil
    end
  end

  describe "holidayCard(externalId:)" do
    let(:query) do
      <<~GRAPHQL
        query HolidayCard($externalId: String!) {
          holidayCard(externalId: $externalId) {
            id externalId title size templateId designConfig
            photos { blobId filename contentType byteSize url }
          }
        }
      GRAPHQL
    end

    it "returns the caller's own card" do
      card = create(:holiday_card, user:, title: "Shen family 2026")

      result = exec(query, variables: { externalId: card.external_id }).dig("data", "holidayCard")

      expect(result["title"]).to eq("Shen family 2026")
      expect(result["designConfig"]).to eq({})
      expect(result["photos"]).to eq([])
    end

    describe "the proof fields" do
      let(:proof_query) do
        <<~GRAPHQL
          query HolidayCard($externalId: String!) {
            holidayCard(externalId: $externalId) {
              proofUrl proofGeneratedAt proofCurrent proofApproved
            }
          }
        GRAPHQL
      end

      def proof_for(card)
        exec(proof_query, variables: { externalId: card.external_id }).dig("data", "holidayCard")
      end

      it "report nothing for a card that has never been proofed" do
        result = proof_for(create(:holiday_card, user:))

        expect(result["proofUrl"]).to be_nil
        expect(result["proofGeneratedAt"]).to be_nil
        expect(result["proofCurrent"]).to be(false)
        expect(result["proofApproved"]).to be(false)
      end

      # The state the editor has to be able to draw: there *is* a PDF to show,
      # and it is out of date. "Has a proofUrl" and "proofCurrent" have to be
      # separately answerable for that.
      it "keep the URL of a proof the design has moved past, but report it stale" do
        card = create(:holiday_card, user:)
        card.update!(proof_url: "https://example.test/proof.pdf", proof_generated_at: Time.current,
                     proof_design_digest: card.proof_design_digest_for_current_design)
        card.update!(proof_approved_at: Time.current)
        card.update!(template_id: "another_template")

        result = proof_for(card)

        expect(result["proofUrl"]).to eq("https://example.test/proof.pdf")
        expect(result["proofCurrent"]).to be(false)
        expect(result["proofApproved"]).to be(false)
      end
    end

    it "exposes each attached photo with the blob id design_config points at" do
      card = create(:holiday_card, user:)
      card.photos.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
        filename: "test_image.jpg",
        content_type: "image/jpeg"
      )

      photos = exec(query, variables: { externalId: card.external_id }).dig("data", "holidayCard", "photos")

      expect(photos.length).to eq(1)
      expect(photos.first["blobId"]).to eq(card.photos.blobs.first.id.to_s)
      expect(photos.first["filename"]).to eq("test_image.jpg")
      expect(photos.first["contentType"]).to eq("image/jpeg")
      expect(photos.first["url"]).to be_present
    end

    it "returns nil for someone else's card rather than leaking it" do
      other = create(:holiday_card, title: "Not yours")

      result = exec(query, variables: { externalId: other.external_id })

      expect(result.dig("data", "holidayCard")).to be_nil
      expect(result["errors"]).to be_nil
    end

    it "returns nil for an external_id that does not exist" do
      result = exec(query, variables: { externalId: "ZZZZZZZ" })

      expect(result.dig("data", "holidayCard")).to be_nil
      expect(result["errors"]).to be_nil
    end

    it "returns nil for the caller's own soft-deleted card" do
      card = create(:holiday_card, user:)
      card.delete!

      expect(exec(query, variables: { externalId: card.external_id }).dig("data", "holidayCard")).to be_nil
    end

    it "rejects an unauthenticated caller at the controller" do
      card = create(:holiday_card, user:)
      exec(query, variables: { externalId: card.external_id }, request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    end

    it "rejects an unauthenticated caller smuggled into a public operation name" do
      card = create(:holiday_card, user:)
      smuggled = "query Card($externalId: String!) { holidayCard(externalId: $externalId) { id } }"

      result = exec(
        smuggled,
        variables: { externalId: card.external_id },
        request_headers: anonymous_headers,
        operation_name: "Card"
      )

      expect(result["errors"].map { |e| e["message"] }).to include("Not authenticated")
      expect(result.dig("data", "holidayCard")).to be_nil
    end
  end

  # The dashboard's send summary (#153): counts, so a list of cards needn't pull
  # every order row to say "40 mailed · 2 failed".
  describe "orderSummary" do
    let(:query) do
      <<~GRAPHQL
        query MyHolidayCards {
          myHolidayCards {
            externalId
            orderSummary { total inFlight delivered failed lastOrderedAt }
          }
        }
      GRAPHQL
    end

    def summaries = exec(query).dig("data", "myHolidayCards")

    it "zeroes a card that has never been sent, rather than returning null" do
      create(:holiday_card, user:)

      expect(summaries.first["orderSummary"]).to eq(
        "total" => 0, "inFlight" => 0, "delivered" => 0, "failed" => 0, "lastOrderedAt" => nil
      )
    end

    it "splits orders into in-flight, delivered, and failed" do
      card = create(:holiday_card, user:)
      create(:holiday_card_mail_order, user:, holiday_card: card)
      create(:holiday_card_mail_order, :submitted, user:, holiday_card: card)
      create(:holiday_card_mail_order, :failed, user:, holiday_card: card)
      create(
        :holiday_card_mail_order,
        user:, holiday_card: card, status: HolidayCardMailOrder::COMPLETED
      )

      expect(summaries.first["orderSummary"]).to include(
        "total" => 4, "inFlight" => 2, "delivered" => 1, "failed" => 1
      )
    end

    # `cancelled` is refunded exactly as `failed` is, and means the same thing
    # to the person reading the list: it did not arrive, the money came back.
    it "counts a cancelled order as failed" do
      card = create(:holiday_card, user:)
      create(
        :holiday_card_mail_order,
        user:, holiday_card: card, status: HolidayCardMailOrder::CANCELLED
      )

      expect(summaries.first["orderSummary"]).to include("failed" => 1, "inFlight" => 0)
    end

    it "reports when the card was last sent" do
      card = create(:holiday_card, user:)
      create(:holiday_card_mail_order, user:, holiday_card: card, created_at: 3.days.ago)
      latest = create(:holiday_card_mail_order, user:, holiday_card: card, created_at: 1.hour.ago)

      expect(Time.iso8601(summaries.first["orderSummary"]["lastOrderedAt"]))
        .to be_within(1.second).of(latest.created_at)
    end

    it "does not attribute one card's orders to another" do
      sent = create(:holiday_card, user:, title: "Sent", created_at: 1.hour.ago)
      unsent = create(:holiday_card, user:, title: "Unsent", created_at: 2.hours.ago)
      create(:holiday_card_mail_order, user:, holiday_card: sent)

      totals = summaries.to_h { |card| [ card["externalId"], card["orderSummary"]["total"] ] }

      expect(totals).to eq(sent.external_id => 1, unsent.external_id => 0)
    end

    # The whole reason the field is batch-loaded. Without the dataloader source
    # this is one query per card, which is what a dashboard listing a season's
    # worth of cards would pay on every load.
    it "costs a fixed number of queries however many cards are listed" do
      3.times { create(:holiday_card, user:) }

      queries = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*_, payload|
        queries << payload[:sql] if payload[:sql].include?("holiday_card_mail_orders")
      end
      summaries
      ActiveSupport::Notifications.unsubscribe(subscriber)

      # One grouped count and one grouped maximum, regardless of card count.
      expect(queries.size).to eq(2)
    end
  end
end
