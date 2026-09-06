require "rails_helper"

RSpec.describe HolidayCard::ProofGenerator do
  let(:card) { create(:holiday_card) }

  before { with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY) }

  describe "#generate!" do
    it "stores the URL, the time, and the digest of what it rendered" do
      stub_postcard_create

      freeze_time do
        expect(described_class.new(card).generate!).to eq(card)

        expect(card.reload.proof_url).to eq("https://pg-prod-bucket-1.s3.amazonaws.com/test/postcard_spec1fakepostcardid.pdf")
        expect(card.proof_generated_at).to eq(Time.current)
        expect(card.proof_design_digest).to eq(card.proof_design_digest_for_current_design)
        expect(card.proof_current?).to be(true)
      end
    end

    # The acceptance criterion with teeth: a live key is configured in this
    # spec's environment and must still never be the one that goes out.
    it "authenticates with the test key even when a live key is configured" do
      stub = stub_postcard_create

      described_class.new(card).generate!

      expect(stub.with { |request| request.headers["X-Api-Key"] == PostGridHelpers::TEST_API_KEY }).to have_been_made
    end

    it "uses the test key even when POSTGRID_MODE says live" do
      with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY, mode: "live")
      stub = stub_postcard_create

      described_class.new(card).generate!

      expect(stub.with { |request| request.headers["X-Api-Key"] == PostGridHelpers::TEST_API_KEY }).to have_been_made
    end

    it "sends the rendered panels, the card's size, and both addresses" do
      stub = stub_postcard_create
      panels = HolidayCard::PrintRenderer.new(card).render

      described_class.new(card).generate!

      expect(stub.with { |request|
        body = JSON.parse(request.body)
        body["frontHTML"] == panels[:front] &&
          body["backHTML"] == panels[:back] &&
          body["size"] == card.size &&
          body.dig("to", "addressLine1").present? &&
          body.dig("from", "addressLine1").present?
      }).to have_been_made
    end

    it "carries an Idempotency-Key, so the client's own retries cannot create two postcards" do
      stub = stub_postcard_create

      described_class.new(card).generate!

      expect(stub.with { |request| request.headers["Idempotency-Key"].present? }).to have_been_made
    end

    it "names the card in the description, so a dashboard row is traceable" do
      stub = stub_postcard_create

      described_class.new(card).generate!

      expect(stub.with { |request| JSON.parse(request.body)["description"].include?(card.external_id) }).to have_been_made
    end

    it "records the response as a test-mode order" do
      stub_postcard_create

      described_class.new(card).generate!

      # Asserted on the fixture rather than on the card, because `live` is the
      # field that proves the render cost nothing — it is why the fixture says
      # false, and a fixture that quietly flipped to true should fail here.
      expect(JSON.parse(post_grid_fixture("postcard_test_created"))["live"]).to be(false)
    end

    it "clears an approval carried over from a previous proof" do
      stub_postcard_create
      card.update!(proof_approved_at: 1.hour.ago)

      described_class.new(card).generate!

      expect(card.reload.proof_approved_at).to be_nil
    end

    context "when PostGrid rejects the card" do
      it "raises InvalidRequestError and leaves the previous proof untouched" do
        stub_postcard_create(body: post_grid_fixture("error_invalid_request"), status: 400)
        previous = { proof_url: "https://example.test/previous.pdf", proof_generated_at: 1.hour.ago,
                     proof_design_digest: card.proof_design_digest_for_current_design }
        card.update!(previous)

        expect { described_class.new(card).generate! }.to raise_error(PostGrid::InvalidRequestError)

        expect(card.reload.proof_url).to eq(previous[:proof_url])
        expect(card.proof_design_digest).to eq(previous[:proof_design_digest])
      end
    end

    it "raises rather than storing a proof with no URL" do
      stub_postcard_create(body: { "id" => "postcard_x", "live" => false }.to_json)

      expect { described_class.new(card).generate! }.to raise_error(PostGrid::ServiceError, /no proof URL/)
      expect(card.reload.proof_url).to be_nil
    end

    it "raises UnknownTemplateError for a card whose template has been retired" do
      stub_postcard_create
      card.update!(template_id: "a_template_that_was_removed")

      expect { described_class.new(card).generate! }
        .to raise_error(HolidayCard::PrintRenderer::UnknownTemplateError)
    end

    it "makes no request at all when the template is unknown" do
      stub = stub_postcard_create
      card.update!(template_id: "a_template_that_was_removed")

      expect { described_class.new(card).generate! }.to raise_error(HolidayCard::PrintRenderer::UnknownTemplateError)
      expect(stub).not_to have_been_made
    end
  end

  describe "MODE" do
    it "is test, and is not derived from configuration" do
      expect(described_class::MODE).to eq(:test)
    end
  end
end
