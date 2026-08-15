require "rails_helper"

RSpec.describe "Holiday card queries", type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  def exec(query, variables: {}, request_headers: headers, operation_name: nil)
    body = { query:, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  describe "myHolidayCards" do
    let(:query) do
      <<~GRAPHQL
        query MyHolidayCards {
          myHolidayCards { id externalId title size templateId designConfig createdAt updatedAt }
        }
      GRAPHQL
    end

    it "returns only the caller's cards, newest first" do
      create(:holiday_card, user:, title: "Older", created_at: 2.days.ago)
      create(:holiday_card, user:, title: "Newer", created_at: 1.hour.ago)
      create(:holiday_card, title: "Someone else's")

      result = exec(query).dig("data", "myHolidayCards")

      expect(result.map { |c| c["title"] }).to eq([ "Newer", "Older" ])
    end

    it "omits a soft-deleted card" do
      create(:holiday_card, user:, title: "Kept")
      create(:holiday_card, user:, title: "Gone").delete!

      result = exec(query).dig("data", "myHolidayCards")

      expect(result.map { |c| c["title"] }).to eq([ "Kept" ])
    end

    it "rejects an unauthenticated caller at the controller" do
      exec(query, request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    end

    # PUBLIC_OPERATIONS is matched against the operation *name*, so a caller can
    # skip the controller gate by naming their operation "Card". The resolver
    # has to answer for itself.
    it "rejects an unauthenticated caller smuggled into a public operation name" do
      smuggled = "query Card { myHolidayCards { id } }"
      result = exec(smuggled, request_headers: anonymous_headers, operation_name: "Card")

      expect(result["errors"].map { |e| e["message"] }).to include("Not authenticated")
      expect(result.dig("data", "myHolidayCards")).to be_nil
    end
  end

  describe "holidayCard(externalId:)" do
    let(:query) do
      <<~GRAPHQL
        query HolidayCard($externalId: String!) {
          holidayCard(externalId: $externalId) {
            id externalId title size templateId designConfig
            photos { blobId filename contentType byteSize url }
          }
        }
      GRAPHQL
    end

    it "returns the caller's own card" do
      card = create(:holiday_card, user:, title: "Shen family 2026")

      result = exec(query, variables: { externalId: card.external_id }).dig("data", "holidayCard")

      expect(result["title"]).to eq("Shen family 2026")
      expect(result["designConfig"]).to eq({})
      expect(result["photos"]).to eq([])
    end

    it "exposes each attached photo with the blob id design_config points at" do
      card = create(:holiday_card, user:)
      card.photos.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
        filename: "test_image.jpg",
        content_type: "image/jpeg"
      )

      photos = exec(query, variables: { externalId: card.external_id }).dig("data", "holidayCard", "photos")

      expect(photos.length).to eq(1)
      expect(photos.first["blobId"]).to eq(card.photos.blobs.first.id.to_s)
      expect(photos.first["filename"]).to eq("test_image.jpg")
      expect(photos.first["contentType"]).to eq("image/jpeg")
      expect(photos.first["url"]).to be_present
    end

    it "returns nil for someone else's card rather than leaking it" do
      other = create(:holiday_card, title: "Not yours")

      result = exec(query, variables: { externalId: other.external_id })

      expect(result.dig("data", "holidayCard")).to be_nil
      expect(result["errors"]).to be_nil
    end

    it "returns nil for an external_id that does not exist" do
      result = exec(query, variables: { externalId: "ZZZZZZZ" })

      expect(result.dig("data", "holidayCard")).to be_nil
      expect(result["errors"]).to be_nil
    end

    it "returns nil for the caller's own soft-deleted card" do
      card = create(:holiday_card, user:)
      card.delete!

      expect(exec(query, variables: { externalId: card.external_id }).dig("data", "holidayCard")).to be_nil
    end

    it "rejects an unauthenticated caller at the controller" do
      card = create(:holiday_card, user:)
      exec(query, variables: { externalId: card.external_id }, request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    end

    it "rejects an unauthenticated caller smuggled into a public operation name" do
      card = create(:holiday_card, user:)
      smuggled = "query Card($externalId: String!) { holidayCard(externalId: $externalId) { id } }"

      result = exec(
        smuggled,
        variables: { externalId: card.external_id },
        request_headers: anonymous_headers,
        operation_name: "Card"
      )

      expect(result["errors"].map { |e| e["message"] }).to include("Not authenticated")
      expect(result.dig("data", "holidayCard")).to be_nil
    end
  end
end
