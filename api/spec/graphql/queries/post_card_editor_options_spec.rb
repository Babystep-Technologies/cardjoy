require "rails_helper"

RSpec.describe Queries::PostCardEditorOptions, type: :request do
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:query) do
    <<~GRAPHQL
      query PostCardEditorOptions {
        postCardEditorOptions {
          designConfigVersion
          cardSizes
          fonts { key name fallback }
          textSizes { key points }
          alignments
          lineHeight
          textMaxLength
          minZoom
          maxZoom
          maxPan
          maxPhotos
        }
      }
    GRAPHQL
  end

  def options
    post "/graphql", params: { query:, variables: {}, operationName: "PostCardEditorOptions" }.to_json,
      headers: anonymous_headers
    JSON.parse(response.body).dig("data", "postCardEditorOptions")
  end

  # Same argument as the template catalogue: this is reference data compiled
  # into the release, identical for every caller, so it needs no session.
  it "answers an unauthenticated caller" do
    expect(options).to be_present
    expect(response).to have_http_status(:ok)
  end

  it "offers exactly the fonts the model validates against, in that order" do
    expect(options["fonts"].map { |font| font["key"] }).to eq(PostCard::VALID_FONTS)
  end

  it "labels each font the way the print renderer names it" do
    playfair = options["fonts"].find { |font| font["key"] == "playfair" }

    expect(playfair).to include("name" => "Playfair Display", "fallback" => "serif")
  end

  it "reports the type scale in points so a preview can match the print" do
    expect(options["textSizes"]).to eq([
      { "key" => "sm", "points" => 9.0 },
      { "key" => "md", "points" => 12.0 },
      { "key" => "lg", "points" => 18.0 },
      { "key" => "xl", "points" => 28.0 }
    ])
  end

  it "reports the limits the model and renderer enforce" do
    expect(options).to include(
      "designConfigVersion" => PostCard::CURRENT_DESIGN_CONFIG_VERSION,
      "cardSizes" => PostCard::VALID_SIZES,
      "alignments" => PostCardCatalogue::ALIGNMENTS,
      "lineHeight" => PostCard::PrintRenderer::LINE_HEIGHT,
      "textMaxLength" => PostCard::TEXT_CONTENT_MAX_LENGTH,
      "minZoom" => PostCard::MIN_ZOOM,
      "maxZoom" => PostCard::MAX_ZOOM,
      "maxPan" => PostCard::PrintRenderer::MAX_PAN,
      "maxPhotos" => PostCard::MAX_PHOTOS
    )
  end

  # The whole point of this query is that the client stops keeping its own copy.
  # If a font ships without a vendored face the editor would offer something the
  # printer cannot render, so the two lists have to stay identical.
  it "offers no font the print renderer cannot embed" do
    expect(options["fonts"].map { |font| font["key"] }).to all(satisfy { |key| PostCard::PrintFonts.face(key) })
  end

  it "names every size the templates declare as a default" do
    declared = PostCardCatalogue.templates.flat_map do |template|
      template.panels.flat_map { |panel| panel.text_regions.map(&:default_size) }
    end.uniq

    expect(options["textSizes"].map { |size| size["key"] }).to include(*declared)
  end
end
