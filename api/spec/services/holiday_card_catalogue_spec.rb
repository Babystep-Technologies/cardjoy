require "rails_helper"
require "tempfile"

RSpec.describe HolidayCardCatalogue do
  describe "the shipped catalogue" do
    # This is the guard rail for every template we will ever add. A template
    # that fails here would print with a cropped face or get the mailing
    # rejected, and neither is visible until money has been spent, so it has to
    # fail in CI instead.
    it "violates no print constraint" do
      expect(described_class.violations).to eq([])
    end

    it "ships 3 templates at each size" do
      expect(described_class.templates(size: "6x4").length).to eq(3)
      expect(described_class.templates(size: "6x9").length).to eq(3)
    end

    it "covers 1, 3, and 5 photo layouts at each size, so the editor has real variety" do
      HolidayCard::VALID_SIZES.each do |size|
        counts = described_class.templates(size:).map { |template| template.front.photo_slots.length }

        expect(counts).to match_array([ 1, 3, 5 ])
      end
    end

    it "only uses sizes the model accepts" do
      expect(described_class.templates.map(&:size).uniq).to match_array(HolidayCard::VALID_SIZES)
    end

    it "ships 12 stickers across 3 categories" do
      expect(described_class.stickers.length).to eq(12)
      expect(described_class.sticker_categories).to match_array(%w[snowflakes botanicals wordmarks])
    end
  end

  # Spelled out rather than left to `violations` so a failure names the actual
  # rule that broke.
  describe "print geometry" do
    it "keeps every region inside the safe margin" do
      described_class.templates.each do |template|
        template.panels.each do |panel|
          panel.regions.each do |region|
            expect(template.safe_box.contains?(region.rect)).to be(true),
              "#{template.id}/#{panel.name}/#{region.id} is outside the safe margin"
          end
        end
      end
    end

    it "paints every background across the full bleed" do
      described_class.templates.each do |template|
        bleed_box = template.bleed_box

        expect(bleed_box.x).to eq(-described_class::BLEED)
        expect(bleed_box.y).to eq(-described_class::BLEED)
        expect(bleed_box.right).to eq(template.width + described_class::BLEED)
        expect(bleed_box.bottom).to eq(template.height + described_class::BLEED)

        template.panels.each do |panel|
          expect(panel.background).to match(described_class::HEX_COLOR_FORMAT),
            "#{template.id}/#{panel.name} has no fillable background colour"
        end
      end
    end

    it "keeps every back-panel region clear of the reserved PostGrid address block" do
      described_class.templates.each do |template|
        template.back.regions.each do |region|
          expect(region.rect.overlaps?(template.reserved_address_block)).to be(false),
            "#{template.id}/back/#{region.id} overlaps the address block"
        end
      end
    end

    it "leaves the front panel free to use the whole card" do
      # The address block is a back-panel constraint only. If this ever starts
      # failing it means someone applied it to the front by mistake.
      overlapping = described_class.templates.select do |template|
        template.front.regions.any? { |region| region.rect.overlaps?(template.reserved_address_block) }
      end

      expect(overlapping).not_to be_empty
    end

    it "gives every slot a unique id within its panel" do
      described_class.templates.each do |template|
        template.panels.each do |panel|
          ids = panel.regions.map(&:id)

          expect(ids.uniq.length).to eq(ids.length), "#{template.id}/#{panel.name} reuses a slot id"
        end
      end
    end

    it "gives every template a unique id" do
      ids = described_class.templates.map(&:id)

      expect(ids.uniq.length).to eq(ids.length)
    end

    it "only defaults to fonts the model accepts" do
      fonts = described_class.templates.flat_map { |t| t.panels.flat_map { |p| p.text_regions.map(&:default_font) } }

      expect(fonts.uniq - HolidayCard::VALID_FONTS).to eq([])
    end
  end

  describe ".templates" do
    it "returns every template when no size is given" do
      expect(described_class.templates.length).to eq(6)
    end

    it "filters by size" do
      expect(described_class.templates(size: "6x4").map(&:size).uniq).to eq([ "6x4" ])
    end

    it "returns an empty list for a size that does not exist" do
      expect(described_class.templates(size: "10x10")).to eq([])
    end

    it "memoizes, so the YAML is read once per process" do
      described_class.templates

      expect(YAML).not_to receive(:load_file)

      described_class.templates
    end
  end

  describe ".template" do
    it "finds a template by id" do
      expect(described_class.template("snowy_trio").name).to eq("Snowy Trio")
    end

    # A design_config stored before a template was retired still names it, and
    # that has to degrade rather than 500.
    it "returns nil for an unknown id rather than raising" do
      expect(described_class.template("no_such_template")).to be_nil
    end

    it "returns nil for a blank id" do
      expect(described_class.template(nil)).to be_nil
      expect(described_class.template("")).to be_nil
    end
  end

  describe ".stickers" do
    it "filters by category" do
      stickers = described_class.stickers(category: "snowflakes")

      expect(stickers).to be_present
      expect(stickers.map(&:category).uniq).to eq([ "snowflakes" ])
    end

    it "returns an empty list for a category that does not exist" do
      expect(described_class.stickers(category: "nope")).to eq([])
    end

    it "returns nil for an unknown sticker id rather than raising" do
      expect(described_class.sticker("no_such_sticker")).to be_nil
    end
  end

  describe "sticker assets" do
    it "ships a readable SVG for every entry" do
      described_class.stickers.each do |sticker|
        expect(sticker.svg).to start_with("<"), "#{sticker.id} is not an SVG document"
        expect(sticker.svg).to include("<svg")
      end
    end

    it "inlines the artwork as a data URI both the editor and the renderer can use" do
      sticker = described_class.sticker("snowflake_fine")

      expect(sticker.data_uri).to start_with("data:image/svg+xml;base64,")
      expect(Base64.decode64(sticker.data_uri.split(",").last)).to eq(sticker.svg)
    end
  end

  describe "Rect" do
    let(:block) { described_class::Rect.new(x: 3.0, y: 0.0, w: 3.0, h: 4.0) }

    it "detects an overlap" do
      expect(described_class::Rect.new(x: 2.5, y: 1.0, w: 1.0, h: 1.0).overlaps?(block)).to be(true)
    end

    # Floats make anything stricter flaky, and a region ending exactly where the
    # reserved block begins is legal.
    it "does not count a shared edge as an overlap" do
      expect(described_class::Rect.new(x: 0.25, y: 1.0, w: 2.75, h: 1.0).overlaps?(block)).to be(false)
    end

    it "detects containment" do
      expect(block.contains?(described_class::Rect.new(x: 3.5, y: 1.0, w: 1.0, h: 1.0))).to be(true)
      expect(block.contains?(described_class::Rect.new(x: 3.5, y: 1.0, w: 3.0, h: 1.0))).to be(false)
    end
  end

  describe "validation" do
    around do |example|
      example.run
    ensure
      described_class.reset!
    end

    def with_catalogue(templates)
      file = Tempfile.new([ "templates", ".yml" ])
      file.write(templates.to_yaml)
      file.flush
      described_class.reset!
      stub_const("#{described_class}::TEMPLATES_PATH", file.path)
      yield
    ensure
      file.close!
    end

    let(:valid_template) do
      {
        "id" => "test", "name" => "Test", "size" => "6x4",
        "front" => {
          "background" => "#FFFFFF",
          "photo_slots" => [ { "id" => "photo_1", "x" => 0.25, "y" => 0.25, "w" => 5.5, "h" => 3.0 } ],
          "text_regions" => [], "sticker_regions" => []
        },
        "back" => { "background" => "#FFFFFF", "photo_slots" => [], "text_regions" => [], "sticker_regions" => [] }
      }
    end

    it "accepts a well-formed template" do
      with_catalogue([ valid_template ]) do
        expect(described_class.templates.map(&:id)).to eq([ "test" ])
      end
    end

    it "rejects a slot that breaks the safe margin" do
      template = valid_template.deep_dup
      template["front"]["photo_slots"].first["x"] = 0.1

      with_catalogue([ template ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /safe margin/)
      end
    end

    it "rejects a back-panel region that overlaps the address block" do
      template = valid_template.deep_dup
      template["back"]["text_regions"] = [
        { "id" => "message", "x" => 0.25, "y" => 0.25, "w" => 5.5, "h" => 1.0,
          "align" => "left", "default_font" => "poppins", "default_size" => "sm" }
      ]

      with_catalogue([ template ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /reserved address block/)
      end
    end

    it "rejects a background that cannot be painted to the bleed" do
      template = valid_template.deep_dup
      template["front"]["background"] = "white"

      with_catalogue([ template ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /cannot be painted to the bleed/)
      end
    end

    it "rejects a duplicate slot id within a panel" do
      template = valid_template.deep_dup
      template["front"]["photo_slots"] << { "id" => "photo_1", "x" => 0.25, "y" => 3.3, "w" => 1.0, "h" => 0.4 }

      with_catalogue([ template ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /reuses the slot id photo_1/)
      end
    end

    it "rejects a duplicate template id" do
      with_catalogue([ valid_template, valid_template.deep_dup ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /duplicate template id test/)
      end
    end

    it "rejects a size the model does not accept" do
      template = valid_template.deep_dup
      template["size"] = "8x10"

      with_catalogue([ template ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /unknown size 8x10/)
      end
    end

    it "rejects a text region defaulting to a font the model would reject" do
      template = valid_template.deep_dup
      template["front"]["text_regions"] = [
        { "id" => "greeting", "x" => 0.25, "y" => 3.3, "w" => 5.5, "h" => 0.4,
          "align" => "center", "default_font" => "comic_sans", "default_size" => "lg" }
      ]

      with_catalogue([ template ]) do
        expect { described_class.templates }
          .to raise_error(described_class::InvalidCatalogueError, /unknown font/)
      end
    end

    it "does not memoize a catalogue it rejected" do
      template = valid_template.deep_dup
      template["front"]["photo_slots"].first["x"] = 0.1

      with_catalogue([ template ]) do
        expect { described_class.templates }.to raise_error(described_class::InvalidCatalogueError)
        expect { described_class.templates }.to raise_error(described_class::InvalidCatalogueError)
      end
    end
  end
end
