require "rails_helper"

RSpec.describe Mutations::ApproveHolidayCardProof, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:card) { create(:holiday_card, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation ApproveHolidayCardProof($externalId: String!) {
        approveHolidayCardProof(input: { externalId: $externalId }) {
          holidayCard { externalId proofUrl proofCurrent proofApproved }
          errors
        }
      }
    GRAPHQL
  end

  # What ProofGenerator leaves behind. Written directly so this spec exercises
  # approval alone and never touches PostGrid.
  def store_proof(on: card, at: Time.current)
    on.update!(
      proof_url: "https://example.test/proof.pdf",
      proof_generated_at: at,
      proof_design_digest: on.proof_design_digest_for_current_design
    )
    on
  end

  def approve(external_id: card.external_id, request_headers: headers)
    post "/graphql", params: { query:, variables: { externalId: external_id } }.to_json, headers: request_headers
    JSON.parse(response.body).dig("data", "approveHolidayCardProof")
  end

  it "approves a current proof" do
    store_proof

    freeze_time do
      result = approve

      expect(result["errors"]).to be_empty
      expect(result.dig("holidayCard", "proofApproved")).to be(true)
      expect(card.reload.proof_approved_at).to eq(Time.current)
    end
  end

  it "refuses a card that has no proof yet" do
    result = approve

    expect(result["errors"]).to eq([ described_class::NO_PROOF_ERROR ])
    expect(card.reload.proof_approved_at).to be_nil
  end

  # The bug this issue exists to prevent: what the user says yes to has to be
  # what prints.
  it "refuses a proof whose design has moved since it was rendered" do
    store_proof
    card.update!(design_config: { "version" => 1, "front" => { "texts" => { "greeting" => { "content" => "Changed" } } } })

    result = approve

    expect(result["errors"]).to eq([ described_class::STALE_PROOF_ERROR ])
    expect(card.reload.proof_approved_at).to be_nil
  end

  it "refuses a proof whose template has changed" do
    store_proof
    card.update!(template_id: "another_template")

    expect(approve["errors"]).to eq([ described_class::STALE_PROOF_ERROR ])
  end

  it "refuses a proof whose size has changed" do
    store_proof
    card.update!(size: "6x9")

    expect(approve["errors"]).to eq([ described_class::STALE_PROOF_ERROR ])
  end

  # Nothing was edited here, so no invalidation callback fires — the PDF link
  # has simply aged past the point where PostGrid may still serve it.
  it "refuses a proof older than the staleness window" do
    store_proof(at: HolidayCard::PROOF_MAX_AGE.ago - 1.minute)

    expect(approve["errors"]).to eq([ described_class::STALE_PROOF_ERROR ])
    expect(card.reload.proof_approved_at).to be_nil
  end

  it "drops an existing approval when the card is edited afterwards" do
    store_proof
    approve
    expect(card.reload.proof_approved_at).to be_present

    card.update!(design_config: { "version" => 1, "back" => { "texts" => { "message" => { "content" => "Edited" } } } })

    expect(card.reload.proof_approved_at).to be_nil
    expect(card.proof_approved?).to be(false)
  end

  it "returns Not authorized for another user's card" do
    other_card = store_proof(on: create(:holiday_card, user: create(:user)))

    result = approve(external_id: other_card.external_id)

    expect(result["errors"]).to eq([ "Not authorized" ])
    expect(other_card.reload.proof_approved_at).to be_nil
  end

  it "returns a not-found error for an unknown card" do
    expect(approve(external_id: "ZZZZZZZ")["errors"]).to eq([ "Holiday card not found" ])
  end

  it "is rejected outright without a token" do
    store_proof

    post "/graphql", params: { query:, variables: { externalId: card.external_id } }.to_json, headers: anonymous_headers

    expect(response).to have_http_status(:unauthorized)
    expect(card.reload.proof_approved_at).to be_nil
  end

  it "returns Not authenticated for a caller smuggled in under a public operation name" do
    store_proof
    smuggled = <<~GRAPHQL
      mutation Card($externalId: String!) {
        approveHolidayCardProof(input: { externalId: $externalId }) { holidayCard { externalId } errors }
      }
    GRAPHQL

    post "/graphql",
      params: { query: smuggled, operationName: "Card", variables: { externalId: card.external_id } }.to_json,
      headers: anonymous_headers
    result = JSON.parse(response.body).dig("data", "approveHolidayCardProof")

    expect(result["errors"]).to eq([ "Not authenticated" ])
    expect(card.reload.proof_approved_at).to be_nil
  end
end
