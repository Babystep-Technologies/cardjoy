require "rails_helper"

RSpec.describe Mutations::UpdateHolidayCard, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:card) { create(:holiday_card, user:, title: "Draft") }

  let(:query) do
    <<~GRAPHQL
      mutation UpdateHolidayCard($externalId: String!, $title: String, $templateId: String, $designConfig: JSON) {
        updateHolidayCard(input: {
          externalId: $externalId, title: $title, templateId: $templateId, designConfig: $designConfig
        }) {
          holidayCard { externalId title templateId designConfig }
          errors
        }
      }
    GRAPHQL
  end

  # A document with two stickers on the front, so a later save can drop one.
  def config_with_stickers(sticker_ids)
    {
      "version" => 1,
      "front" => {
        "texts" => { "greeting" => { "content" => "Merry Christmas", "font" => "playfair", "color" => "#123456" } },
        "stickers" => sticker_ids.map { |id| { "sticker_id" => id, "region_id" => "corner_tl" } }
      },
      "back" => {}
    }
  end

  def exec(variables, request_headers: headers, gql: query, operation_name: nil)
    body = { query: gql, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  def update(variables)
    exec({ externalId: card.external_id }.merge(variables)).dig("data", "updateHolidayCard")
  end

  it "updates the title" do
    result = update(title: "Shen family 2026")

    expect(result["errors"]).to be_empty
    expect(card.reload.title).to eq("Shen family 2026")
  end

  it "replaces the design config wholesale rather than merging it" do
    update(designConfig: config_with_stickers(%w[holly_sprig mistletoe]))
    expect(card.reload.design_config.dig("front", "stickers").length).to eq(2)

    result = update(designConfig: config_with_stickers(%w[holly_sprig]))

    expect(result["errors"]).to be_empty
    stickers = card.reload.design_config.dig("front", "stickers")
    expect(stickers.map { |s| s["sticker_id"] }).to eq([ "holly_sprig" ])
  end

  it "drops a whole panel's contents when the document no longer has them" do
    update(designConfig: config_with_stickers(%w[holly_sprig]))

    update(designConfig: { "version" => 1, "front" => {}, "back" => {} })

    expect(card.reload.design_config["front"]).to eq({})
  end

  it "leaves the design config alone when only the title is sent" do
    update(designConfig: config_with_stickers(%w[holly_sprig]))

    update(title: "Renamed")

    expect(card.reload.design_config.dig("front", "stickers").length).to eq(1)
  end

  it "surfaces a model validation failure as errors rather than a 500" do
    invalid = { "version" => 1, "front" => { "texts" => { "greeting" => { "font" => "comic_sans" } } } }

    result = update(designConfig: invalid)

    expect(response).to have_http_status(:ok)
    expect(result["holidayCard"]).to be_nil
    expect(result["errors"].join).to include("invalid font")
    expect(card.reload.design_config).to eq({})
  end

  it "rejects an unknown design config version as errors" do
    result = update(designConfig: { "version" => 99, "front" => {} })

    expect(result["errors"].join).to include("unknown version")
  end

  describe "templateId" do
    # Switching layout is an edit: the user keeps their photos and their message
    # and changes the arrangement, so the editor sends the re-mapped document
    # alongside the new id in one save.
    it "switches the card to another template of the same size" do
      result = update(templateId: "single_moment")

      expect(result["errors"]).to be_empty
      expect(card.reload.template_id).to eq("single_moment")
    end

    it "saves the re-mapped document and the new template together" do
      remapped = { "version" => 1, "front" => { "texts" => { "greeting" => { "content" => "Happy Holidays" } } }, "back" => {} }

      update(templateId: "single_moment", designConfig: remapped)

      expect(card.reload.template_id).to eq("single_moment")
      expect(card.design_config.dig("front", "texts", "greeting", "content")).to eq("Happy Holidays")
    end

    # A template's geometry is drawn for one panel size, so a 6x9 layout on a
    # 6x4 card would push every slot past the trim line.
    it "refuses a template drawn for a different size" do
      result = update(templateId: "winter_portrait")

      expect(result["errors"]).to eq([ "Template winter_portrait is not available in size 6x4" ])
      expect(card.reload.template_id).to eq("snowy_trio")
    end

    it "refuses a template that is not in the catalogue" do
      result = update(templateId: "no_such_template")

      expect(result["errors"]).to eq([ "Unknown template" ])
      expect(card.reload.template_id).to eq("snowy_trio")
    end

    it "leaves the template alone when it is not sent" do
      update(title: "Renamed")

      expect(card.reload.template_id).to eq("snowy_trio")
    end

    # template_id is one of HolidayCard::PROOF_DESIGN_FIELDS, so a layout change
    # has to invalidate an approval the same way a content change does.
    it "clears a proof approval" do
      card.update!(proof_url: "https://example.com/proof.pdf", proof_generated_at: Time.current,
        proof_design_digest: card.proof_design_digest_for_current_design, proof_approved_at: Time.current)

      update(templateId: "single_moment")

      expect(card.reload.proof_approved_at).to be_nil
      expect(card).not_to be_proof_approved
    end
  end

  it "returns Not authorized for another user's card" do
    other = create(:holiday_card)

    result = exec({ externalId: other.external_id, title: "Hijacked" }).dig("data", "updateHolidayCard")

    expect(result["errors"]).to eq([ "Not authorized" ])
    expect(other.reload.title).not_to eq("Hijacked")
  end

  it "returns not found for an unknown external id" do
    result = exec({ externalId: "ZZZZZZZ", title: "x" }).dig("data", "updateHolidayCard")

    expect(result["errors"]).to eq([ "Holiday card not found" ])
  end

  it "rejects an unauthenticated caller smuggled into a public operation name" do
    smuggled = <<~GRAPHQL
      mutation Card($externalId: String!) {
        updateHolidayCard(input: { externalId: $externalId, title: "x" }) { holidayCard { externalId } errors }
      }
    GRAPHQL

    result = exec({ externalId: card.external_id }, request_headers: anonymous_headers, gql: smuggled, operation_name: "Card")
      .dig("data", "updateHolidayCard")

    expect(result["errors"]).to eq([ "Not authenticated" ])
  end
end
