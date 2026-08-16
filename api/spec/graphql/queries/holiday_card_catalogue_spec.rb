require "rails_helper"

RSpec.describe "Holiday card catalogue queries", type: :request do
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  def exec(query, variables: {}, operation_name: nil, request_headers: anonymous_headers)
    body = { query:, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  describe "holidayCardTemplates" do
    let(:query) do
      <<~GRAPHQL
        query HolidayCardTemplates($size: String) {
          holidayCardTemplates(size: $size) {
            id name description size
            widthInches heightInches bleedInches safeMarginInches
            bleedBox { x y w h }
            safeBox { x y w h }
            reservedAddressBlock { x y w h }
            front {
              name background
              photoSlots { id radius rect { x y w h } }
              textRegions { id align defaultFont defaultSize rect { x y w h } }
              stickerRegions { id rect { x y w h } }
            }
            back {
              name background
              photoSlots { id }
              textRegions { id }
              stickerRegions { id }
            }
          }
        }
      GRAPHQL
    end

    # The catalogue is identical for every caller and touches no database, so the
    # marketing page can preview templates before anyone signs in.
    it "answers an unauthenticated caller" do
      templates = exec(query, operation_name: "HolidayCardTemplates").dig("data", "holidayCardTemplates")

      expect(response).to have_http_status(:ok)
      expect(templates.length).to eq(6)
    end

    it "filters by size" do
      templates = exec(query, variables: { size: "6x9" }, operation_name: "HolidayCardTemplates")
        .dig("data", "holidayCardTemplates")

      expect(templates.length).to eq(3)
      expect(templates.map { |t| t["size"] }.uniq).to eq([ "6x9" ])
    end

    it "returns an empty list for a size that does not exist" do
      templates = exec(query, variables: { size: "10x10" }, operation_name: "HolidayCardTemplates")
        .dig("data", "holidayCardTemplates")

      expect(templates).to eq([])
    end

    it "exposes the geometry the editor needs to place a slot" do
      template = exec(query, variables: { size: "6x4" }, operation_name: "HolidayCardTemplates")
        .dig("data", "holidayCardTemplates")
        .find { |t| t["id"] == "snowy_trio" }

      expect(template["widthInches"]).to eq(6.0)
      expect(template["heightInches"]).to eq(4.0)
      expect(template["bleedInches"]).to eq(0.125)
      expect(template["safeMarginInches"]).to eq(0.25)
      # The background is painted from outside the trim line.
      expect(template["bleedBox"]).to eq({ "x" => -0.125, "y" => -0.125, "w" => 6.25, "h" => 4.25 })
      expect(template["safeBox"]).to eq({ "x" => 0.25, "y" => 0.25, "w" => 5.5, "h" => 3.5 })
      expect(template["reservedAddressBlock"]).to eq({ "x" => 3.0, "y" => 0.0, "w" => 3.0, "h" => 4.0 })

      slot = template.dig("front", "photoSlots").first
      expect(slot["id"]).to eq("photo_1")
      expect(slot["rect"]).to eq({ "x" => 0.25, "y" => 0.25, "w" => 2.4, "h" => 2.85 })
      expect(slot["radius"]).to eq(0.1)

      greeting = template.dig("front", "textRegions").first
      expect(greeting["align"]).to eq("center")
      expect(greeting["defaultFont"]).to eq("playfair")
      expect(greeting["defaultSize"]).to eq("lg")
    end
  end

  describe "holidayCardStickers" do
    let(:query) do
      <<~GRAPHQL
        query HolidayCardStickers($category: String) {
          holidayCardStickers(category: $category) { id name category dataUri }
        }
      GRAPHQL
    end

    it "answers an unauthenticated caller with every sticker" do
      stickers = exec(query, operation_name: "HolidayCardStickers").dig("data", "holidayCardStickers")

      expect(response).to have_http_status(:ok)
      expect(stickers.length).to eq(12)
    end

    it "filters by category" do
      stickers = exec(query, variables: { category: "wordmarks" }, operation_name: "HolidayCardStickers")
        .dig("data", "holidayCardStickers")

      expect(stickers.map { |s| s["id"] }).to include("happy_holidays")
      expect(stickers.map { |s| s["category"] }.uniq).to eq([ "wordmarks" ])
    end

    it "returns an empty list for a category that does not exist" do
      stickers = exec(query, variables: { category: "nope" }, operation_name: "HolidayCardStickers")
        .dig("data", "holidayCardStickers")

      expect(stickers).to eq([])
    end

    # The editor renders this straight into an <img src>, and the print renderer
    # embeds the same bytes.
    it "inlines the artwork as a data URI" do
      sticker = exec(query, operation_name: "HolidayCardStickers")
        .dig("data", "holidayCardStickers")
        .find { |s| s["id"] == "holly_sprig" }

      expect(sticker["dataUri"]).to start_with("data:image/svg+xml;base64,")
      expect(Base64.decode64(sticker["dataUri"].split(",").last)).to include("<svg")
    end
  end
end
