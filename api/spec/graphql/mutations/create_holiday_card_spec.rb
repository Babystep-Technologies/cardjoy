require "rails_helper"

RSpec.describe Mutations::CreateHolidayCard, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateHolidayCard($title: String, $size: String!, $templateId: String!) {
        createHolidayCard(input: { title: $title, size: $size, templateId: $templateId }) {
          holidayCard { id externalId title size templateId designConfig }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, request_headers: headers, gql: query, operation_name: nil)
    body = { query: gql, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  def create_card(overrides = {})
    exec({ title: "Shen family 2026", size: "6x4", templateId: "snowy_trio" }.merge(overrides))
      .dig("data", "createHolidayCard")
  end

  it "creates a card from a catalogue template" do
    result = create_card

    expect(result["errors"]).to be_empty
    card = result["holidayCard"]
    expect(card["title"]).to eq("Shen family 2026")
    expect(card["size"]).to eq("6x4")
    expect(card["templateId"]).to eq("snowy_trio")
    expect(user.holiday_cards.count).to eq(1)
  end

  it "seeds a valid empty design config and generates an external id" do
    card = create_card["holidayCard"]

    expect(card["designConfig"]).to eq(
      "version" => HolidayCard::CURRENT_DESIGN_CONFIG_VERSION,
      "front" => { "photos" => {}, "texts" => {}, "stickers" => [] },
      "back" => { "photos" => {}, "texts" => {}, "stickers" => [] }
    )
    expect(card["externalId"]).to match(/\A[A-Z]{7}\z/)
    # The seeded document has to survive the model's own validator, or the very
    # first save from the editor would fail.
    expect(HolidayCard.last).to be_valid
  end

  it "creates a card without a title" do
    result = create_card(title: nil)

    expect(result["errors"]).to be_empty
    expect(result.dig("holidayCard", "title")).to be_nil
  end

  # Regression guard for the epic's cost decision: a holiday card is paid for at
  # send time out of the postage wallet, so designing one is free. See the
  # comment on Mutations::CreateHolidayCard.
  it "does not spend a credit" do
    # Touch `headers` first so the user — and the signup_bonus credit their
    # creation writes — exists before the ledger is measured.
    headers

    expect { create_card }.not_to change(Credit, :count)
    expect(user.credits.where(reason: "card_created")).to be_empty
  end

  it "creates a card for a user with no credits at all" do
    user.credits.delete_all

    expect(create_card["errors"]).to be_empty
  end

  it "rejects an unknown template id" do
    result = create_card(templateId: "no_such_template")

    expect(result["errors"]).to eq([ "Unknown template" ])
    expect(result["holidayCard"]).to be_nil
    expect(HolidayCard.count).to eq(0)
  end

  it "rejects an invalid size" do
    result = create_card(size: "8x10")

    expect(result["errors"]).to eq([ "Invalid size" ])
    expect(HolidayCard.count).to eq(0)
  end

  it "rejects a template whose size does not match the requested size" do
    # winter_portrait is a 6x9 template.
    result = create_card(size: "6x4", templateId: "winter_portrait")

    expect(result["errors"]).to eq([ "Template winter_portrait is not available in size 6x4" ])
    expect(HolidayCard.count).to eq(0)
  end

  it "rejects an unauthenticated caller at the controller" do
    exec({ title: "x", size: "6x4", templateId: "snowy_trio" }, request_headers: anonymous_headers)

    expect(response).to have_http_status(:unauthorized)
  end

  # PUBLIC_OPERATIONS is matched against the operation *name*, so a caller can
  # skip the controller gate by naming the operation "Card". The resolver has to
  # answer for itself.
  it "rejects an unauthenticated caller smuggled into a public operation name" do
    smuggled = <<~GRAPHQL
      mutation Card {
        createHolidayCard(input: { size: "6x4", templateId: "snowy_trio" }) { holidayCard { id } errors }
      }
    GRAPHQL

    result = exec({}, request_headers: anonymous_headers, gql: smuggled, operation_name: "Card")
      .dig("data", "createHolidayCard")

    expect(result["errors"]).to eq([ "Not authenticated" ])
    expect(result["holidayCard"]).to be_nil
  end
end
