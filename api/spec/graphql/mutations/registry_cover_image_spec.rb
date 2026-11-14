require "rails_helper"

RSpec.describe "Registry cover image", type: :request do
  let(:user) { create(:user) }
  let(:list) { create(:wish_list, :standalone, user: user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:headers) do
    { "Authorization" => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" }
  end

  let(:set_query) do
    <<~GRAPHQL
      mutation SetCover($registryExternalId: String!, $coverImageFile: Upload!) {
        setRegistryCoverImage(input: { registryExternalId: $registryExternalId, coverImageFile: $coverImageFile }) {
          wishList { externalId coverImageUrl }
          errors
        }
      }
    GRAPHQL
  end

  def upload(file, id: list.external_id, as: headers)
    post "/graphql",
      params: {
        operations: { query: set_query, variables: { registryExternalId: id, coverImageFile: nil } }.to_json,
        map: { "0" => [ "variables.coverImageFile" ] }.to_json,
        "0" => file
      },
      headers: as.merge("Content-Type" => "multipart/form-data")
    JSON.parse(response.body).dig("data", "setRegistryCoverImage")
  end

  it "attaches an image for the owner and exposes its URL" do
    result = upload(fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg"))

    expect(result["errors"]).to be_empty
    expect(result.dig("wishList", "coverImageUrl")).to be_present
    expect(list.reload.cover_image).to be_attached
  end

  it "rejects a non-image and keeps the current cover" do
    upload(fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg"))
    before = list.reload.cover_image.blob.id

    result = upload(fixture_file_upload("spec/fixtures/files/test_document.pdf", "application/pdf"))

    expect(result["errors"].join).to include("PNG, JPEG, GIF or WebP")
    expect(list.reload.cover_image.blob.id).to eq(before)
  end

  it "won't touch someone else's registry" do
    other = create(:wish_list, :standalone)

    result = upload(fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg"), id: other.external_id)

    expect(result["errors"]).to eq([ "Registry not found" ])
    expect(other.reload.cover_image).not_to be_attached
  end

  it "removes the cover" do
    upload(fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg"))

    post "/graphql",
      params: { query: "mutation { removeRegistryCoverImage(input: { registryExternalId: \"#{list.external_id}\" }) { errors } }" }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    expect(JSON.parse(response.body).dig("data", "removeRegistryCoverImage", "errors")).to be_empty
    expect(list.reload.cover_image).not_to be_attached
  end
end
