require "rails_helper"

RSpec.describe Mutations::DeleteHolidayCardPhoto, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:card) { create(:holiday_card, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation DeleteHolidayCardPhoto($externalId: String!, $blobId: ID!) {
        deleteHolidayCardPhoto(input: { externalId: $externalId, blobId: $blobId }) {
          holidayCard { externalId designConfig photos { blobId } }
          errors
        }
      }
    GRAPHQL
  end

  def attach_photo(holiday_card, filename)
    holiday_card.photos.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
      filename:,
      content_type: "image/jpeg"
    )
    holiday_card.photos.blobs.find { |blob| blob.filename.to_s == filename }
  end

  def exec(variables, request_headers: headers, gql: query, operation_name: nil)
    body = { query: gql, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  def delete_photo(blob_id, external_id: card.external_id)
    exec({ externalId: external_id, blobId: blob_id.to_s }).dig("data", "deleteHolidayCardPhoto")
  end

  it "detaches the photo" do
    blob = attach_photo(card, "family.jpg")

    result = delete_photo(blob.id)

    expect(result["errors"]).to be_empty
    expect(result.dig("holidayCard", "photos")).to be_empty
    expect(card.reload.photos.count).to eq(0)
  end

  it "strips every reference to the photo from design_config and leaves the card valid" do
    doomed = attach_photo(card, "doomed.jpg")
    kept = attach_photo(card, "kept.jpg")
    card.update!(design_config: {
      "version" => 1,
      "front" => {
        "photos" => {
          "photo_1" => { "blob_id" => doomed.id, "zoom" => 1.2 },
          "photo_2" => { "blob_id" => kept.id },
          "photo_3" => { "blob_id" => doomed.id }
        },
        "texts" => { "greeting" => { "content" => "Merry Christmas" } }
      },
      "back" => { "photos" => { "photo_1" => { "blob_id" => doomed.id } } }
    })

    result = delete_photo(doomed.id)

    expect(result["errors"]).to be_empty
    config = card.reload.design_config
    expect(config.dig("front", "photos").keys).to eq([ "photo_2" ])
    expect(config.dig("back", "photos")).to eq({})
    # Untouched parts of the document survive the scrub.
    expect(config.dig("front", "texts", "greeting", "content")).to eq("Merry Christmas")
    expect(card.photos.blobs.map(&:id)).to eq([ kept.id ])
    # The whole point: the card can still be saved afterwards.
    expect(card).to be_valid
  end

  # blobId arrives as a GraphQL ID (a string), so a document that stored the id
  # as a string must be scrubbed just the same as one that stored a number.
  it "scrubs a reference stored as a string id" do
    blob = attach_photo(card, "family.jpg")
    card.update!(design_config: {
      "version" => 1,
      "front" => { "photos" => { "photo_1" => { "blob_id" => blob.id.to_s } } }
    })

    delete_photo(blob.id)

    expect(card.reload.design_config.dig("front", "photos")).to eq({})
  end

  it "leaves a card with no references untouched" do
    blob = attach_photo(card, "family.jpg")
    card.update!(design_config: { "version" => 1, "front" => { "stickers" => [ { "sticker_id" => "holly_sprig" } ] } })

    delete_photo(blob.id)

    expect(card.reload.design_config.dig("front", "stickers").length).to eq(1)
  end

  it "returns an error for a blob that is not on this card" do
    other_card = create(:holiday_card, user:)
    blob = attach_photo(other_card, "elsewhere.jpg")

    result = delete_photo(blob.id)

    expect(result["errors"]).to eq([ "Photo not found on this card" ])
    expect(other_card.reload.photos.count).to eq(1)
  end

  it "returns Not authorized for another user's card" do
    other = create(:holiday_card)
    blob = attach_photo(other, "family.jpg")

    result = delete_photo(blob.id, external_id: other.external_id)

    expect(result["errors"]).to eq([ "Not authorized" ])
    expect(other.reload.photos.count).to eq(1)
  end

  it "returns not found for an unknown external id" do
    result = delete_photo(1, external_id: "ZZZZZZZ")

    expect(result["errors"]).to eq([ "Holiday card not found" ])
  end

  it "rejects an unauthenticated caller smuggled into a public operation name" do
    blob = attach_photo(card, "family.jpg")
    smuggled = <<~GRAPHQL
      mutation Card($externalId: String!, $blobId: ID!) {
        deleteHolidayCardPhoto(input: { externalId: $externalId, blobId: $blobId }) {
          holidayCard { externalId }
          errors
        }
      }
    GRAPHQL

    result = exec({ externalId: card.external_id, blobId: blob.id.to_s },
      request_headers: anonymous_headers, gql: smuggled, operation_name: "Card")
      .dig("data", "deleteHolidayCardPhoto")

    expect(result["errors"]).to eq([ "Not authenticated" ])
    expect(card.reload.photos.count).to eq(1)
  end
end
