require "rails_helper"

RSpec.describe PostCard::ProofGenerator do
  let(:card) { create(:post_card, user: create(:user, :with_return_address)) }

  before { with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY) }

  describe "#generate!" do
    it "stores the URL, the time, and the digest of what it rendered" do
      stub_postcard_create

      freeze_time do
        expect(described_class.new(card).generate!).to eq(card)

        expect(card.reload.proof_url).to eq(JSON.parse(post_grid_fixture("postcard_test_fetched"))["url"])
        expect(card.proof_generated_at).to eq(Time.current)
        expect(card.proof_design_digest).to eq(card.proof_design_digest_for_current_design)
        expect(card.proof_current?).to be(true)
      end
    end

    # The GET this fixes in for (#233): `create`'s response never carries
    # `url`, confirmed against a real PostGrid response, so the proof's PDF
    # only exists once this second call fetches the postcard back by id.
    it "fetches the created postcard by id to get its url" do
      stub_postcard_create
      get_stub = stub_postcard_get

      described_class.new(card).generate!

      expect(get_stub.with { |request|
        request.headers["X-Api-Key"] == PostGridHelpers::TEST_API_KEY
      }).to have_been_made
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
      panels = PostCard::PrintRenderer.new(card).render

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

    # The real failure mode (#233): `create` never carries `url` — only the
    # follow-up `fetch` does — so this is what "no URL" actually looks like
    # now: a fetched postcard that, for whatever reason, still has none.
    it "raises rather than storing a proof with no URL" do
      stub_postcard_create
      stub_postcard_get(body: { "id" => "postcard_spec1fakepostcardid", "status" => "ready" }.to_json)

      expect { described_class.new(card).generate! }.to raise_error(PostGrid::ServiceError, /no proof URL/)
      expect(card.reload.proof_url).to be_nil
    end

    it "raises and makes no GET at all when create answers with no id" do
      stub = stub_postcard_get
      stub_postcard_create(body: { "status" => "ready" }.to_json)

      expect { described_class.new(card).generate! }.to raise_error(PostGrid::ServiceError, /no postcard id/)
      expect(stub).not_to have_been_made
    end

    it "raises UnknownTemplateError for a card whose template has been retired" do
      stub_postcard_create
      card.update!(template_id: "a_template_that_was_removed")

      expect { described_class.new(card).generate! }
        .to raise_error(PostCard::PrintRenderer::UnknownTemplateError)
    end

    it "makes no request at all when the template is unknown" do
      stub = stub_postcard_create
      card.update!(template_id: "a_template_that_was_removed")

      expect { described_class.new(card).generate! }.to raise_error(PostCard::PrintRenderer::UnknownTemplateError)
      expect(stub).not_to have_been_made
    end

    # The proof's `from` has to match what a real order prints (#233), or
    # approving it proves nothing about the card that actually gets mailed.
    it "sends the card owner's own configured return address as `from`, not the placeholder" do
      stub = stub_postcard_create

      described_class.new(card).generate!

      expect(stub.with { |request|
        from = JSON.parse(request.body)["from"]
        from["addressLine1"] == "123 Market St" && from["city"] == "San Francisco"
      }).to have_been_made
    end

    it "raises a ConfigurationError and makes no request when the card's owner has no return address" do
      bare_card = create(:post_card, user: create(:user))
      stub = stub_postcard_create

      expect { described_class.new(bare_card).generate! }.to raise_error(PostGrid::ConfigurationError)
      expect(stub).not_to have_been_made
    end
  end

  describe "MODE" do
    it "is test, and is not derived from configuration" do
      expect(described_class::MODE).to eq(:test)
    end
  end
end
