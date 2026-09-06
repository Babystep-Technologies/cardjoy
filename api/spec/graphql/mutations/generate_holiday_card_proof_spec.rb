require "rails_helper"

RSpec.describe Mutations::GenerateHolidayCardProof, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:card) { create(:holiday_card, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation GenerateHolidayCardProof($externalId: String!) {
        generateHolidayCardProof(input: { externalId: $externalId }) {
          holidayCard { externalId proofUrl proofGeneratedAt proofCurrent proofApproved }
          errors
        }
      }
    GRAPHQL
  end

  before { with_post_grid_key(live_key: PostGridHelpers::LIVE_API_KEY) }

  def generate(external_id: card.external_id, request_headers: headers)
    post "/graphql", params: { query:, variables: { externalId: external_id } }.to_json, headers: request_headers
    JSON.parse(response.body).dig("data", "generateHolidayCardProof")
  end

  it "generates a proof and reports it as current but not yet approved" do
    stub_postcard_create

    result = generate

    expect(result["errors"]).to be_empty
    expect(result.dig("holidayCard", "proofUrl")).to eq("https://pg-prod-bucket-1.s3.amazonaws.com/test/postcard_spec1fakepostcardid.pdf")
    expect(result.dig("holidayCard", "proofGeneratedAt")).to be_present
    expect(result.dig("holidayCard", "proofCurrent")).to be(true)
    expect(result.dig("holidayCard", "proofApproved")).to be(false)
  end

  # The acceptance criterion. A live key is configured here and must not be the
  # one that leaves the process — a proof that billed someone would be the worst
  # possible outcome of a feature whose whole purpose is to be free.
  it "never calls PostGrid with the live key" do
    stub = stub_postcard_create

    generate

    expect(stub.with { |request| request.headers["X-Api-Key"] == PostGridHelpers::TEST_API_KEY }).to have_been_made
    expect(a_request(:post, PostGridHelpers::POSTCARDS_URL)
      .with(headers: { "X-Api-Key" => PostGridHelpers::LIVE_API_KEY })).not_to have_been_made
  end

  it "persists the digest of what was rendered" do
    stub_postcard_create

    generate

    expect(card.reload.proof_design_digest).to eq(card.proof_design_digest_for_current_design)
  end

  context "when PostGrid rejects the card" do
    it "returns a readable error rather than a 500" do
      stub_postcard_create(body: post_grid_fixture("error_invalid_request"), status: 400)

      result = generate

      expect(response).to have_http_status(:ok)
      expect(result["holidayCard"]).to be_nil
      expect(result["errors"].first).to include("The address is missing a required field")
    end

    it "leaves the previous proof untouched" do
      stub_postcard_create
      generate
      previous_url = card.reload.proof_url
      previous_generated_at = card.proof_generated_at

      # A second stub for the same request wins, so the retry fails where the
      # first attempt succeeded.
      stub_postcard_create(body: post_grid_fixture("error_invalid_request"), status: 400)
      expect(generate["errors"]).not_to be_empty

      expect(card.reload.proof_url).to eq(previous_url)
      expect(card.proof_generated_at).to eq(previous_generated_at)
    end
  end

  it "hides an authentication failure behind a generic message" do
    stub_postcard_create(body: post_grid_fixture("error_unauthorized"), status: 401)

    result = generate

    expect(result["errors"]).to eq([ described_class::UNAVAILABLE_ERROR ])
  end

  it "asks the user to retry when PostGrid is unwell" do
    stub_postcard_create(body: post_grid_fixture("error_server"), status: 503)

    result = generate

    expect(result["errors"]).to eq([ described_class::RETRY_ERROR ])
  end

  it "explains a retired template instead of echoing its id" do
    stub_postcard_create
    card.update!(template_id: "a_template_that_was_removed")

    result = generate

    expect(result["errors"].first).to include("template is no longer available")
    expect(result["errors"].first).not_to include("a_template_that_was_removed")
  end

  # PostGrid is optional app-wide, so an unconfigured deploy degrades rather
  # than 500s — the same gating GIPHY and PostHog get on the frontend.
  it "reports proofs unavailable when no test key is configured" do
    with_post_grid_key(test_key: nil, live_key: PostGridHelpers::LIVE_API_KEY)

    result = generate

    expect(result["errors"]).to eq([ described_class::UNAVAILABLE_ERROR ])
    expect(a_request(:post, PostGridHelpers::POSTCARDS_URL)).not_to have_been_made
  end

  it "returns Not authorized for another user's card" do
    stub_postcard_create
    other_card = create(:holiday_card, user: create(:user))

    result = generate(external_id: other_card.external_id)

    expect(result["errors"]).to eq([ "Not authorized" ])
    expect(other_card.reload.proof_url).to be_nil
  end

  it "is rejected outright without a token" do
    stub_postcard_create

    post "/graphql", params: { query:, variables: { externalId: card.external_id } }.to_json, headers: anonymous_headers

    expect(response).to have_http_status(:unauthorized)
    expect(a_request(:post, PostGridHelpers::POSTCARDS_URL)).not_to have_been_made
  end

  # The controller's auth gate keys on `operationName`, so the mutation's own
  # check is what stops a caller borrowing a public operation's name to get
  # past it. Mirrors the same case in update_holiday_card_spec.
  it "returns Not authenticated for a caller smuggled in under a public operation name" do
    stub_postcard_create
    smuggled = <<~GRAPHQL
      mutation Card($externalId: String!) {
        generateHolidayCardProof(input: { externalId: $externalId }) { holidayCard { externalId } errors }
      }
    GRAPHQL

    post "/graphql",
      params: { query: smuggled, operationName: "Card", variables: { externalId: card.external_id } }.to_json,
      headers: anonymous_headers
    result = JSON.parse(response.body).dig("data", "generateHolidayCardProof")

    expect(result["errors"]).to eq([ "Not authenticated" ])
    expect(a_request(:post, PostGridHelpers::POSTCARDS_URL)).not_to have_been_made
  end

  it "returns a not-found error for an unknown card" do
    result = generate(external_id: "ZZZZZZZ")

    expect(result["errors"]).to eq([ "Holiday card not found" ])
  end
end
