# typed: true
# frozen_string_literal: true

# The holiday card template and sticker catalogue.
#
# Design decision (issue #137): this is a static registry, not a table. It
# follows the precedent docs/ARCHITECTURE.md sets for `Card::OCCASIONS` — some
# domain values are plain Ruby constants rather than tables. Templates are
# design assets that ship with a release and are referenced by every saved
# `HolidayCard#design_config`. A DB table would invite editing the geometry of a
# template that live cards already point at, which would silently re-cut photos
# on a card someone already paid to print. A YAML file under version control
# cannot be edited out from under those cards without a deploy and a diff.
#
# Everything here is in INCHES, measured from the top-left of the trimmed panel,
# because the print renderer and the React preview both derive their pixels from
# the same numbers (px = inches * DPI).
#
# The frontend fetches this over GraphQL rather than mirroring it in TypeScript
# (the `web/src/config/openingMessage` pattern). Two copies of print geometry
# drift, and drift here means a cropped face on a card that has already been
# mailed. One extra round trip on editor load is the cheaper side of that trade.
module HolidayCardCatalogue
  # Raised when a shipped template violates a print constraint. This is a
  # programmer error — the catalogue is committed code, not user input — so it
  # raises rather than returning errors. spec/services/holiday_card_catalogue_spec.rb
  # is the guard rail that makes it fail in CI instead of at print time.
  class InvalidCatalogueError < StandardError; end

  TEMPLATES_PATH = Rails.root.join("config/holiday_card_templates.yml")
  STICKERS_PATH = Rails.root.join("config/holiday_card_stickers.yml")
  STICKER_ASSET_DIR = Rails.root.join("app/assets/holiday_card_stickers")

  # How far the background is printed past the trim line, so a 1/16" drift in
  # the cutter shows card art rather than white paper.
  BLEED = 0.125

  # How far in from the trim line content must stay, for the same reason in
  # reverse: anything closer risks being cut off.
  SAFE_MARGIN = 0.25

  # Trimmed panel size in inches, keyed by HolidayCard::VALID_SIZES. The first
  # number is the width.
  DIMENSIONS = {
    "6x4" => { width: 6.0, height: 4.0 },
    "6x9" => { width: 6.0, height: 9.0 }
  }.freeze

  # The region of the *back* panel PostGrid prints into: the recipient address,
  # the indicia, and the USPS barcode clear zone. Nothing we draw may overlap it.
  #
  # This is the conservative reading — the entire right half of the panel — which
  # is a superset of both conventions that could apply: letter-size mail puts the
  # address block and barcode in the lower right, and USPS flats (the 6x9) want
  # the address in the upper half. Reserving the full-height right half satisfies
  # both without having to know which classification a given card mails under.
  #
  # TODO(#137): tighten these against PostGrid's downloadable per-size template
  # PDFs before the first live print run. Their published design guide
  # (https://postgrid.readme.io/docs/design-and-templates) links per-size PDFs
  # but does not state the rectangles in text, so these are derived from the
  # USPS layout rules rather than copied from PostGrid. Being too conservative
  # costs design space; being too small costs a rejected mailing. The renderer
  # and the editor both read this one constant, so tightening it is a one-line
  # change here.
  RESERVED_ADDRESS_BLOCKS = {
    "6x4" => { x: 3.0, y: 0.0, w: 3.0, h: 4.0 },
    "6x9" => { x: 3.0, y: 0.0, w: 3.0, h: 9.0 }
  }.freeze

  # Type scale the editor offers. The point sizes live in the renderer; these
  # are the names a template may declare as a region's default.
  TEXT_SIZES = %w[sm md lg xl].freeze

  ALIGNMENTS = %w[left center right].freeze

  PANELS = %w[front back].freeze

  # `#rrggbb` only, matching HolidayCard::HEX_COLOR_FORMAT — these are
  # interpolated straight into the print renderer's CSS.
  HEX_COLOR_FORMAT = /\A#\h{6}\z/

  # A rectangle in inches from the top-left of the trimmed panel.
  Rect = Struct.new(:x, :y, :w, :h, keyword_init: true) do
    def right = x + w
    def bottom = y + h

    # Touching edges is not overlapping: a region ending exactly where the
    # reserved block begins is legal, and floats make anything stricter flaky.
    def overlaps?(other)
      x < other.right && right > other.x && y < other.bottom && bottom > other.y
    end

    def contains?(other)
      other.x >= x && other.y >= y && other.right <= right && other.bottom <= bottom
    end

    def to_h = { x:, y:, w:, h: }
  end

  PhotoSlot = Struct.new(:id, :rect, :radius, keyword_init: true)
  TextRegion = Struct.new(:id, :rect, :align, :default_font, :default_size, keyword_init: true)
  StickerRegion = Struct.new(:id, :rect, keyword_init: true)

  Panel = Struct.new(:name, :background, :photo_slots, :text_regions, :sticker_regions, keyword_init: true) do
    # Every placed thing on the panel, for the geometry checks that apply to all
    # of them equally.
    def regions = photo_slots + text_regions + sticker_regions
  end

  Template = Struct.new(:id, :name, :size, :description, :front, :back, keyword_init: true) do
    def panels = [ front, back ]
    def width = HolidayCardCatalogue::DIMENSIONS.fetch(size)[:width]
    def height = HolidayCardCatalogue::DIMENSIONS.fetch(size)[:height]

    # The area content must stay inside.
    def safe_box
      margin = HolidayCardCatalogue::SAFE_MARGIN
      Rect.new(x: margin, y: margin, w: width - (margin * 2), h: height - (margin * 2))
    end

    # The area the background is painted across — the trimmed panel grown by the
    # bleed on all four sides. Origin is negative because it starts outside the
    # trim line.
    def bleed_box
      bleed = HolidayCardCatalogue::BLEED
      Rect.new(x: -bleed, y: -bleed, w: width + (bleed * 2), h: height + (bleed * 2))
    end

    def reserved_address_block
      block = HolidayCardCatalogue::RESERVED_ADDRESS_BLOCKS.fetch(size)
      Rect.new(**block)
    end
  end

  Sticker = Struct.new(:id, :name, :category, :asset, keyword_init: true) do
    def asset_path = HolidayCardCatalogue::STICKER_ASSET_DIR.join(asset)
    def svg = File.read(asset_path)

    # Both consumers want the same thing: the editor puts it in an `<img src>`,
    # the print renderer embeds it. Inlining beats serving a URL — Rails here is
    # API-only with no asset pipeline, and a print job that fetches its own
    # artwork over HTTP can fail halfway through a card.
    def data_uri = "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end

  class << self
    # All templates, or only those of one size. Memoized: the YAML is read once
    # per process.
    def templates(size: nil)
      all = load_templates
      return all if size.blank?

      all.select { |template| template.size == size }
    end

    # nil for an unknown id rather than raising — an id in a stored
    # design_config may name a template a later release retired, and that has to
    # degrade rather than 500.
    def template(id)
      return nil if id.blank?

      templates_by_id[id]
    end

    def stickers(category: nil)
      all = load_stickers
      return all if category.blank?

      all.select { |sticker| sticker.category == category }
    end

    def sticker(id)
      return nil if id.blank?

      stickers_by_id[id]
    end

    def sticker_categories = load_stickers.map(&:category).uniq

    # Every way a shipped template could print badly, as human-readable strings.
    # Public so the spec can report all of them at once instead of dying on the
    # first.
    def violations
      templates = load_templates
      duplicate_ids(templates.map(&:id)).map { |id| "duplicate template id #{id}" } +
        templates.flat_map { |template| template_violations(template) } +
        sticker_violations
    end

    # Test seam: drops the memoized catalogue so a spec can point the loader at
    # a fixture.
    def reset!
      @templates = nil
      @stickers = nil
      @templates_by_id = nil
      @stickers_by_id = nil
    end

    private

    def load_templates
      @templates ||= begin
        parsed = YAML.load_file(TEMPLATES_PATH)
        templates = Array(parsed).map { |attributes| build_template(attributes.with_indifferent_access) }
        assert_valid!(templates)
        templates.freeze
      end
    end

    def load_stickers
      @stickers ||= Array(YAML.load_file(STICKERS_PATH)).map do |attributes|
        attributes = attributes.with_indifferent_access
        Sticker.new(
          id: attributes[:id],
          name: attributes[:name],
          category: attributes[:category],
          asset: attributes[:asset]
        ).freeze
      end.freeze
    end

    def templates_by_id = @templates_by_id ||= load_templates.index_by(&:id)
    def stickers_by_id = @stickers_by_id ||= load_stickers.index_by(&:id)

    def build_template(attributes)
      Template.new(
        id: attributes[:id],
        name: attributes[:name],
        size: attributes[:size],
        description: attributes[:description],
        front: build_panel("front", attributes[:front]),
        back: build_panel("back", attributes[:back])
      ).freeze
    end

    def build_panel(name, attributes)
      attributes = (attributes || {}).with_indifferent_access

      Panel.new(
        name: name,
        background: attributes[:background],
        photo_slots: Array(attributes[:photo_slots]).map { |slot| build_photo_slot(slot.with_indifferent_access) },
        text_regions: Array(attributes[:text_regions]).map { |region| build_text_region(region.with_indifferent_access) },
        sticker_regions: Array(attributes[:sticker_regions]).map { |region| build_sticker_region(region.with_indifferent_access) }
      ).freeze
    end

    def build_photo_slot(attributes)
      PhotoSlot.new(id: attributes[:id], rect: build_rect(attributes), radius: (attributes[:radius] || 0).to_f).freeze
    end

    def build_text_region(attributes)
      TextRegion.new(
        id: attributes[:id],
        rect: build_rect(attributes),
        align: attributes[:align],
        default_font: attributes[:default_font],
        default_size: attributes[:default_size]
      ).freeze
    end

    def build_sticker_region(attributes)
      StickerRegion.new(id: attributes[:id], rect: build_rect(attributes)).freeze
    end

    def build_rect(attributes)
      Rect.new(x: attributes[:x].to_f, y: attributes[:y].to_f, w: attributes[:w].to_f, h: attributes[:h].to_f).freeze
    end

    # Runs on load so a broken catalogue fails on first use in every
    # environment, not only where a spec happens to run.
    def assert_valid!(templates)
      # Set before validating so `violations` can reuse the memoized list
      # without recursing back into the loader.
      @templates = templates
      problems = violations
      return if problems.empty?

      @templates = nil
      raise InvalidCatalogueError, "holiday card catalogue is invalid:\n- #{problems.join("\n- ")}"
    end

    def template_violations(template)
      prefix = "template #{template.id}"
      return [ "#{prefix} has an unknown size #{template.size}" ] unless DIMENSIONS.key?(template.size)

      problems = []
      problems << "#{prefix} has a blank name" if template.name.blank?

      template.panels.each do |panel|
        problems.concat(panel_violations(template, panel))
      end

      problems
    end

    def panel_violations(template, panel)
      prefix = "template #{template.id} panel #{panel.name}"
      problems = []

      # The background is painted across the bleed box, so it has to be a colour
      # the renderer can actually fill with.
      unless panel.background.to_s.match?(HEX_COLOR_FORMAT)
        problems << "#{prefix} background #{panel.background.inspect} is not a #rrggbb colour, so it cannot be painted to the bleed"
      end

      problems.concat(duplicate_ids(panel.regions.map(&:id)).map { |id| "#{prefix} reuses the slot id #{id}" })

      panel.regions.each do |region|
        problems.concat(region_violations(template, panel, region))
      end

      panel.text_regions.each do |region|
        problems << "#{prefix} text #{region.id} has an invalid align #{region.align.inspect}" unless ALIGNMENTS.include?(region.align)
        problems << "#{prefix} text #{region.id} has an unknown font #{region.default_font.inspect}" unless HolidayCard::VALID_FONTS.include?(region.default_font)
        problems << "#{prefix} text #{region.id} has an unknown size #{region.default_size.inspect}" unless TEXT_SIZES.include?(region.default_size)
      end

      problems
    end

    def region_violations(template, panel, region)
      prefix = "template #{template.id} panel #{panel.name}"
      problems = []

      problems << "#{prefix} has a region with a blank id" if region.id.blank?

      rect = region.rect
      if rect.w <= 0 || rect.h <= 0
        problems << "#{prefix} region #{region.id} has a non-positive size"
        return problems
      end

      unless template.safe_box.contains?(rect)
        problems << "#{prefix} region #{region.id} #{format_rect(rect)} falls outside the #{SAFE_MARGIN}\" safe margin #{format_rect(template.safe_box)}"
      end

      if panel.name == "back" && rect.overlaps?(template.reserved_address_block)
        problems << "#{prefix} region #{region.id} #{format_rect(rect)} overlaps the reserved address block #{format_rect(template.reserved_address_block)}"
      end

      problems
    end

    def sticker_violations
      stickers = load_stickers
      problems = duplicate_ids(stickers.map(&:id)).map { |id| "duplicate sticker id #{id}" }

      stickers.each do |sticker|
        problems << "sticker #{sticker.id} has a blank name" if sticker.name.blank?
        problems << "sticker #{sticker.id} has a blank category" if sticker.category.blank?
        problems << "sticker #{sticker.id} is missing its asset #{sticker.asset}" unless File.exist?(sticker.asset_path)
      end

      problems
    end

    def duplicate_ids(ids)
      ids.tally.select { |_id, count| count > 1 }.keys
    end

    def format_rect(rect)
      "(#{rect.x}, #{rect.y}, #{rect.w}x#{rect.h})"
    end
  end
end
