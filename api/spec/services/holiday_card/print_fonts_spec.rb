require "rails_helper"

RSpec.describe HolidayCard::PrintFonts do
  describe "the vendored font set" do
    # A font the model accepts but that has no face here would silently print in
    # the generic fallback, which is exactly the failure vendoring the files was
    # meant to prevent. A face here that the model rejects is dead weight in the
    # repo.
    it "covers HolidayCard::VALID_FONTS exactly" do
      expect(described_class::FACES.keys).to match_array(HolidayCard::VALID_FONTS)
    end

    it "ships every subset file for every face" do
      missing = described_class::FACES.values.flat_map { |face| face.files.values }.reject { |path| File.exist?(path) }

      expect(missing).to eq([])
    end

    it "ships real woff2 files, not placeholders" do
      described_class::FACES.each_value do |face|
        face.files.each_value do |path|
          # "wOF2" is the woff2 magic number. A truncated or HTML-error-page
          # download would still be a file on disk.
          expect(File.binread(path, 4)).to eq("wOF2"), "#{path} is not a woff2 file"
        end
      end
    end
  end

  describe ".css" do
    before { described_class.reset! }

    it "emits one @font-face per subset, with the file inlined as base64" do
      css = described_class.css([ "playfair" ])

      expect(css.scan("@font-face").length).to eq(described_class::SUBSETS.length)
      expect(css).to include("font-family: 'CardJoy Playfair Display';")
      expect(css).to include("src: url(data:font/woff2;base64,")
    end

    it "encodes the actual file bytes" do
      encoded = Base64.strict_encode64(File.binread(described_class::FACES.fetch("cormorant").files.fetch("latin")))

      expect(described_class.css([ "cormorant" ])).to include(encoded)
    end

    it "emits nothing for an unknown font rather than raising" do
      expect(described_class.css([ "comic_sans" ])).to eq("")
    end

    it "emits nothing for no fonts" do
      expect(described_class.css([])).to eq("")
    end

    it "de-duplicates repeated keys" do
      expect(described_class.css(%w[poppins poppins])).to eq(described_class.css([ "poppins" ]))
    end

    it "is stable regardless of the order the fonts were collected in" do
      expect(described_class.css(%w[poppins playfair])).to eq(described_class.css(%w[playfair poppins]))
    end
  end

  describe ".font_stack" do
    it "names the prefixed family and a generic fallback" do
      expect(described_class.font_stack("dancing_script")).to eq("'CardJoy Dancing Script', cursive")
    end

    # The prefix is the point: an unprefixed `font-family: Poppins` could resolve
    # to a system copy on PostGrid's renderer at a different version.
    it "prefixes every family so a system font of the same name cannot win" do
      described_class::FACES.each_value do |face|
        expect(face.css_family).to start_with("CardJoy ")
      end
    end

    it "falls back to a generic family for an unknown font" do
      expect(described_class.font_stack("comic_sans")).to eq("serif")
    end
  end
end
