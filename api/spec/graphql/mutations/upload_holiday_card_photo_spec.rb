require "rails_helper"

RSpec.describe Mutations::UploadHolidayCardPhoto, type: :request do
  include ActionDispatch::TestProcess::FixtureFile

  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Authorization" => "Bearer #{token}", "Content-Type" => "multipart/form-data" } }
  let(:anonymous_headers) { { "Content-Type" => "multipart/form-data" } }

  let(:card) { create(:holiday_card, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation UploadHolidayCardPhoto($externalId: String!, $photoFile: Upload!) {
        uploadHolidayCardPhoto(input: { externalId: $externalId, photoFile: $photoFile }) {
          photo { blobId filename contentType byteSize url }
          errors
        }
      }
    GRAPHQL
  end

  # The smallest thing ActiveStorage will accept as an image, for the tests that
  # care about how *many* photos a card holds rather than what is in them.
  TINY_PNG = Base64.decode64(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
  ).freeze

  def upload(file, external_id: card.external_id, request_headers: headers, gql: query, operation_name: "UploadHolidayCardPhoto")
    post "/graphql",
      params: {
        operations: {
          query: gql,
          operationName: operation_name,
          variables: { externalId: external_id, photoFile: nil }
        }.to_json,
        map: { "0" => [ "variables.photoFile" ] }.to_json,
        "0" => file
      },
      headers: request_headers

    JSON.parse(response.body)
  end

  def jpeg = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")

  def png
    tempfile = Tempfile.new([ "family", ".png" ], binmode: true)
    tempfile.write(TINY_PNG)
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, "image/png")
  end

  it "attaches a JPEG and returns its blob id and url" do
    result = upload(jpeg).dig("data", "uploadHolidayCardPhoto")

    expect(result["errors"]).to be_empty
    photo = result["photo"]
    expect(photo["contentType"]).to eq("image/jpeg")
    expect(photo["url"]).to be_present
    expect(card.reload.photos.count).to eq(1)
    # The returned blob id is exactly what design_config has to point at.
    expect(photo["blobId"]).to eq(card.photos.blobs.first.id.to_s)
  end

  it "attaches a PNG" do
    result = upload(png).dig("data", "uploadHolidayCardPhoto")

    expect(result["errors"]).to be_empty
    expect(result.dig("photo", "contentType")).to eq("image/png")
  end

  it "adds to the existing photos rather than replacing them" do
    upload(png)
    upload(jpeg)

    expect(card.reload.photos.count).to eq(2)
  end

  it "rejects a PDF" do
    pdf = fixture_file_upload("spec/fixtures/files/test_document.pdf", "application/pdf")

    result = upload(pdf).dig("data", "uploadHolidayCardPhoto")

    expect(result["photo"]).to be_nil
    expect(result["errors"]).to eq([ "Photo must be a PNG, JPG, or GIF image." ])
    expect(card.reload.photos.count).to eq(0)
  end

  it "rejects a file over 10MB" do
    tempfile = Tempfile.new([ "huge", ".jpg" ], binmode: true)
    # Real JPEG bytes first so the content-type check passes and the size check
    # is what actually rejects this.
    tempfile.write(File.binread(Rails.root.join("spec/fixtures/files/test_image.jpg")))
    tempfile.write("\0" * (11.megabytes - tempfile.size))
    tempfile.rewind

    result = upload(Rack::Test::UploadedFile.new(tempfile.path, "image/jpeg"))
      .dig("data", "uploadHolidayCardPhoto")

    expect(result["photo"]).to be_nil
    expect(result["errors"]).to eq([ "Photo is too large. Please choose an image smaller than 10MB." ])
    expect(card.reload.photos.count).to eq(0)
  end

  it "rejects the photo past the per-card cap" do
    HolidayCard::MAX_PHOTOS.times do |i|
      card.photos.attach(io: StringIO.new(TINY_PNG), filename: "existing_#{i}.png", content_type: "image/png")
    end

    result = upload(jpeg).dig("data", "uploadHolidayCardPhoto")

    expect(result["photo"]).to be_nil
    expect(result["errors"]).to eq([ "A holiday card can hold at most 20 photos. Remove one before uploading another." ])
    expect(card.reload.photos.count).to eq(HolidayCard::MAX_PHOTOS)
  end

  it "returns Not authorized for another user's card" do
    other = create(:holiday_card)

    result = upload(jpeg, external_id: other.external_id).dig("data", "uploadHolidayCardPhoto")

    expect(result["errors"]).to eq([ "Not authorized" ])
    expect(other.reload.photos.count).to eq(0)
  end

  it "returns not found for an unknown external id" do
    result = upload(jpeg, external_id: "ZZZZZZZ").dig("data", "uploadHolidayCardPhoto")

    expect(result["errors"]).to eq([ "Holiday card not found" ])
  end

  it "rejects an unauthenticated caller smuggled into a public operation name" do
    smuggled = <<~GRAPHQL
      mutation Card($externalId: String!, $photoFile: Upload!) {
        uploadHolidayCardPhoto(input: { externalId: $externalId, photoFile: $photoFile }) {
          photo { blobId }
          errors
        }
      }
    GRAPHQL

    result = upload(jpeg, request_headers: anonymous_headers, gql: smuggled, operation_name: "Card")
      .dig("data", "uploadHolidayCardPhoto")

    expect(result["errors"]).to eq([ "Not authenticated" ])
    expect(card.reload.photos.count).to eq(0)
  end
end
