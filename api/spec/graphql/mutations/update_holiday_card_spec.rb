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
      mutation UpdateHolidayCard($externalId: String!, $title: String, $designConfig: JSON) {
        updateHolidayCard(input: { externalId: $externalId, title: $title, designConfig: $designConfig }) {
          holidayCard { externalId title designConfig }
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
