require "rails_helper"

RSpec.describe HolidayCard::PrintRenderer do
  let(:template) { HolidayCardCatalogue.template("snowy_trio") }

  # ------------------------------------------------------------------ fixtures

  def attach_photo(card)
    card.photos.attach(
      io: File.open(Rails.root.join("spec/fixtures/files/test_image.jpg")),
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
    card.photos.blobs.last
  end

  def new_card(template, design_config = {})
    card = create(:holiday_card, size: template.size, template_id: template.id)
    card.update!(design_config:) if design_config.present?
    card
  end

  # A card with every photo slot, text region, and sticker region on both panels
  # filled. Geometry assertions want the complete output of a template, not the
  # handful of slots one hand-written fixture happens to use.
  def filled_card(template)
    card = create(:holiday_card, size: template.size, template_id: template.id)
    blob = attach_photo(card)
    card.update!(design_config: {
      "version" => HolidayCard::CURRENT_DESIGN_CONFIG_VERSION,
      "front" => filled_panel(template.front, blob),
      "back" => filled_panel(template.back, blob)
    })
    card
  end

  def filled_panel(panel, blob)
    {
      "photos" => panel.photo_slots.to_h do |slot|
        [ slot.id, { "blob_id" => blob.id, "pan_x" => 0.1, "pan_y" => -0.05, "zoom" => 1.2 } ]
      end,
      "texts" => panel.text_regions.to_h { |region| [ region.id, { "content" => "Merry Christmas" } ] },
      "stickers" => panel.sticker_regions.map { |region| { "region_id" => region.id, "sticker_id" => "holly_sprig" } }
    }
  end

  # A card whose front greeting is exactly `text`, on a template that has one.
  def card_with_greeting(text, extra = {})
    new_card(template, {
      "version" => 1,
      "front" => { "texts" => { "greeting" => { "content" => text }.merge(extra) } }
    })
  end

  # ------------------------------------------------------------------- parsing

  def parse(html) = Nokogiri::HTML5(html)

  def render(card) = described_class.new(card).render

  def declarations(node)
    node["style"].to_s.split(";").filter_map do |declaration|
      property, value = declaration.split(":", 2)
      [ property.strip, value.strip ] if value
    end.to_h
  end

  def to_inches(value) = value.to_s.delete_suffix("in").to_f

  # Every content element's box, keyed by slot id and expressed back in
  # *catalogue* coordinates — inches from the top-left of the trimmed panel,
  # with the bleed offset undone — so it compares directly against the YAML.
  def rendered_rects(html)
    parse(html).css(".cj-photo, .cj-text, .cj-sticker").to_h do |node|
      style = declarations(node)
      [ node["data-slot"], {
        x: (to_inches(style.fetch("left")) - HolidayCardCatalogue::BLEED).round(4),
        y: (to_inches(style.fetch("top")) - HolidayCardCatalogue::BLEED).round(4),
        w: to_inches(style.fetch("width")).round(4),
        h: to_inches(style.fetch("height")).round(4)
      } ]
    end
  end

  def catalogue_rects(panel)
    panel.regions.to_h { |region| [ region.id, region.rect.to_h.transform_values { |value| value.round(4) } ] }
  end

  def stylesheet(html) = parse(html).at_css("style").content

  # The `@font-face` families in the document, as font names. Reads the
  # stylesheet rather than the whole document so an inline `font-family` on a
  # text box cannot be mistaken for an embedded face.
  def embedded_families(html)
    stylesheet(html).scan(/@font-face\s*\{[^}]*font-family:\s*'CardJoy ([^']+)'/).flatten.uniq.sort
  end

  # The base64 payloads dwarf the markup and happen to contain every two-letter
  # sequence there is, so any scan of the document has to drop them first.
  def without_payloads(html) = html.gsub(%r{base64,[A-Za-z0-9+/=]+}, "base64,PAYLOAD")

  # ---------------------------------------------------------------- the basics

  describe "#render" do
    it "returns a front and a back HTML document" do
      result = render(filled_card(template))

      expect(result.keys).to match_array(%i[front back])
      result.each_value do |html|
        expect(html).to be_a(String)
        # No leading whitespace before the doctype: it can put a parser into
        # quirks mode, and quirks mode is a differently-laid-out card.
        expect(html).to start_with("<!DOCTYPE html>")
        expect(parse(html).at_css(".cj-panel")).to be_present
      end
    end

    it "raises for a template the catalogue no longer ships" do
      card = create(:holiday_card, template_id: "retired_template")

      expect { render(card) }.to raise_error(described_class::UnknownTemplateError, /retired_template/)
    end

    # The whole point of the "returns two strings" design: no HTTP client to
    # stub, nothing to time out mid-render. Stickers are read off disk and fonts
    # come from the repo.
    it "makes no HTTP request of its own" do
      render(filled_card(template))

      expect(a_request(:any, //)).not_to have_been_made
    end
  end

  # -------------------------------------------------------------- the geometry

  describe "document size" do
    HolidayCard::VALID_SIZES.each do |size|
      it "is the #{size} trim plus a #{HolidayCardCatalogue::BLEED}\" bleed on every edge" do
        template = HolidayCardCatalogue.templates(size:).first
        width = template.width + (HolidayCardCatalogue::BLEED * 2)
        height = template.height + (HolidayCardCatalogue::BLEED * 2)

        render(filled_card(template)).each_value do |html|
          expect(html).to include("@page { size: #{width}in #{height}in; margin: 0; }")
          expect(html).to include("html, body { margin: 0; padding: 0; width: #{width}in; height: #{height}in; }")

          panel = declarations(parse(html).at_css(".cj-panel"))
          expect(panel["width"]).to eq("#{width}in")
          expect(panel["height"]).to eq("#{height}in")
        end
      end
    end
  end

  HolidayCardCatalogue.templates.each do |catalogue_template|
    describe "template #{catalogue_template.id}" do
      let(:rendered) { render(filled_card(catalogue_template)) }

      it "places every slot at its catalogue coordinates, offset for the bleed" do
        catalogue_template.panels.each do |panel|
          expect(rendered_rects(rendered.fetch(panel.name.to_sym)))
            .to eq(catalogue_rects(panel)), "#{catalogue_template.id} #{panel.name} panel"
        end
      end

      # The rectangle PostGrid prints the recipient address, indicia, and
      # barcode into. Anything of ours inside it gets the mailing rejected, and
      # that is only discovered after the print run is paid for.
      it "paints nothing inside the reserved address block on the back" do
        reserved = catalogue_template.reserved_address_block

        overlapping = rendered_rects(rendered.fetch(:back)).select do |_id, rect|
          HolidayCardCatalogue::Rect.new(**rect).overlaps?(reserved)
        end

        expect(overlapping).to eq({})
      end
    end
  end

  # No shipped template can reach this — the catalogue refuses to load one whose
  # regions overlap the reserved block — so it is exercised against a template
  # that only exists here. It is the backstop for the template we add badly one
  # day.
  it "drops a region that would overlap the reserved address block" do
    over_the_line = HolidayCardCatalogue::TextRegion.new(
      id: "over_the_line",
      rect: HolidayCardCatalogue::Rect.new(x: 3.5, y: 1.0, w: 2.0, h: 0.5),
      align: "left", default_font: "poppins", default_size: "sm"
    )
    blank = HolidayCardCatalogue::Panel.new(
      name: "front", background: "#FFFFFF", photo_slots: [], text_regions: [], sticker_regions: []
    )
    bad_template = HolidayCardCatalogue::Template.new(
      id: "bad_template", name: "Bad", size: "6x4", description: "",
      front: blank,
      back: HolidayCardCatalogue::Panel.new(
        name: "back", background: "#FFFFFF", photo_slots: [], text_regions: [ over_the_line ], sticker_regions: []
      )
    )
    allow(HolidayCardCatalogue).to receive(:template).with("bad_template").and_return(bad_template)
    card = create(:holiday_card, template_id: "bad_template")
    card.update!(design_config: {
      "version" => 1, "back" => { "texts" => { "over_the_line" => { "content" => "In the address block" } } }
    })

    expect(render(card)[:back]).not_to include("In the address block")
  end

  it "expresses every length in inches or points, never pixels" do
    lengths = without_payloads(render(filled_card(template))[:front]).scan(/-?[\d.]+(?:in|pt|px|em|rem)\b/)

    expect(lengths).to be_present
    expect(lengths.grep_v(/(?:in|pt)\z/)).to eq([])
  end

  # ----------------------------------------------------------------- the fonts

  describe "fonts" do
    it "embeds only the fonts the panel actually paints with" do
      card = new_card(template, {
        "version" => 1,
        "front" => { "texts" => { "greeting" => { "content" => "Happy Holidays", "font" => "montserrat" } } },
        "back" => { "texts" => { "signoff" => { "content" => "The Shens", "font" => "dancing_script" } } }
      })

      rendered = render(card)

      expect(embedded_families(rendered[:front])).to eq([ "Montserrat" ])
      expect(embedded_families(rendered[:back])).to eq([ "Dancing Script" ])
    end

    it "falls back to the template's default font when the design config names none" do
      # snowy_trio's greeting defaults to playfair.
      expect(embedded_families(render(card_with_greeting("Happy Holidays"))[:front])).to eq([ "Playfair Display" ])
    end

    it "embeds nothing for a panel with no text on it" do
      expect(embedded_families(render(card_with_greeting("Happy Holidays"))[:back])).to eq([])
    end

    it "embeds them as base64, with no external font URL anywhere in the output" do
      html = render(card_with_greeting("Happy Holidays"))[:front]

      expect(html).to include("src: url(data:font/woff2;base64,")
      expect(without_payloads(html)).not_to match(%r{url\(\s*['"]?https?://})
      expect(html).not_to include("fonts.googleapis.com")
      expect(html).not_to include("fonts.gstatic.com")
    end

    it "points the text at the embedded face" do
      style = declarations(parse(render(card_with_greeting("Hi"))[:front]).at_css(".cj-text"))

      expect(style["font-family"]).to eq("'CardJoy Playfair Display', serif")
    end
  end

  # ------------------------------------------------------------- the user text

  describe "user text" do
    it "renders a greeting of <script>alert(1)</script> as visible text, not markup" do
      html = render(card_with_greeting("<script>alert(1)</script>"))[:front]

      expect(parse(html).css("script")).to be_empty
      expect(parse(html).at_css(".cj-text").text).to eq("<script>alert(1)</script>")
      expect(html).to include("&lt;script&gt;alert(1)&lt;/script&gt;")
    end

    it "escapes quotes and ampersands rather than letting them close an attribute" do
      html = render(card_with_greeting(%(Ben & Jerry's "best" <year>)))[:front]

      expect(parse(html).at_css(".cj-text").text).to eq(%(Ben & Jerry's "best" <year>))
    end

    it "keeps newlines as line breaks" do
      html = render(card_with_greeting("Merry Christmas\nfrom the Shens"))[:front]

      expect(parse(html).at_css(".cj-text").inner_html).to eq("Merry Christmas<br>from the Shens")
    end

    it "skips a text region the user left empty" do
      html = render(card_with_greeting("   "))[:front]

      expect(parse(html).css(".cj-text")).to be_empty
    end

    # Every value that reaches the CSS is allow-listed, because design_config is
    # user input and this document goes to a third party. These documents could
    # not be saved through the model's validator today; a stored one could
    # predate it.
    it "ignores a colour that is not a hex triplet" do
      card = card_with_greeting("Hi")
      card.design_config = card.design_config.deep_merge(
        "front" => { "texts" => { "greeting" => { "color" => "red;position:fixed;left:0" } } }
      )

      html = render(card)[:front]

      expect(html).not_to include("position:fixed")
      expect(declarations(parse(html).at_css(".cj-text"))["color"]).to eq(described_class::DARK_TEXT)
    end

    it "ignores a font and an alignment that are not on the allow-list" do
      card = card_with_greeting("Hi")
      card.design_config = card.design_config.deep_merge(
        "front" => { "texts" => { "greeting" => { "font" => "comic_sans", "align" => "justify}" } } }
      )

      style = declarations(parse(render(card)[:front]).at_css(".cj-text"))

      expect(style["font-family"]).to eq("'CardJoy Playfair Display', serif")
      expect(style["text-align"]).to eq("center")
    end

    it "uses the template's type scale and a size the design config overrides it with" do
      md = declarations(parse(render(card_with_greeting("Hi", "size" => "md"))[:front]).at_css(".cj-text"))
      default = declarations(parse(render(card_with_greeting("Hi"))[:front]).at_css(".cj-text"))

      expect(md["font-size"]).to eq("#{described_class::POINT_SIZES.fetch('md')}pt")
      # snowy_trio's greeting defaults to lg.
      expect(default["font-size"]).to eq("#{described_class::POINT_SIZES.fetch('lg')}pt")
    end

    it "picks a light default text colour on a dark template background" do
      dark = HolidayCardCatalogue.template("festive_five") # front background #1F3A5F
      card = new_card(dark, {
        "version" => 1, "front" => { "texts" => { "greeting" => { "content" => "Happy Holidays" } } }
      })

      style = declarations(parse(render(card)[:front]).at_css(".cj-text"))

      expect(style["color"]).to eq(described_class::LIGHT_TEXT)
    end

    it "clips text to its region so it cannot spill across the card" do
      style = declarations(parse(render(card_with_greeting("Hi"))[:front]).at_css(".cj-text"))

      expect(style["overflow"]).to eq("hidden")
    end
  end

  # ----------------------------------------------------------------- the photos

  describe "photos" do
    let(:card) { create(:holiday_card, size: template.size, template_id: template.id) }
    let(:blob) { attach_photo(card) }

    # Assigned rather than saved, so an example can render a document the
    # model's validator would refuse today — a card stored before a rule existed
    # still has to print.
    def placing(photo)
      card.design_config = { "version" => 1, "front" => { "photos" => { "photo_1" => photo } } }
      card
    end

    def placed = placing("blob_id" => blob.id, "pan_x" => 0.1, "pan_y" => -0.05, "zoom" => 1.2)

    def photo_image(html) = parse(html).at_css(".cj-photo-image")

    it "turns pan and zoom into an exact transform" do
      style = declarations(photo_image(render(placed)[:front]))

      expect(style["transform"]).to eq("translate(10%, -5%) scale(1.2)")
      expect(style["transform-origin"]).to eq("center center")
      expect(style["object-fit"]).to eq("cover")
    end

    it "defaults to no pan and no zoom" do
      style = declarations(photo_image(render(placing("blob_id" => blob.id))[:front]))

      expect(style["transform"]).to eq("translate(0%, 0%) scale(1)")
    end

    it "clamps a zoom and a pan from outside the allowed range" do
      card = placing("blob_id" => blob.id, "pan_x" => 9, "pan_y" => -9, "zoom" => 99)

      expect(declarations(photo_image(render(card)[:front]))["transform"])
        .to eq("translate(100%, -100%) scale(#{HolidayCard::MAX_ZOOM.to_i})")
    end

    it "clips the photo to its slot, with the template's corner radius" do
      style = declarations(parse(render(placed)[:front]).at_css(".cj-photo"))

      expect(style["overflow"]).to eq("hidden")
      expect(style["border-radius"]).to eq("0.1in")
    end

    it "matches a blob id the design config carries as a string" do
      expect(photo_image(render(placing("blob_id" => blob.id.to_s))[:front])).to be_present
    end

    it "leaves a slot empty rather than raising when its blob is gone" do
      html = render(placing("blob_id" => 0))[:front]

      expect(parse(html).css(".cj-photo").length).to eq(template.front.photo_slots.length)
      expect(parse(html).css(".cj-photo-image")).to be_empty
    end

    it "survives a saved document, not just an assigned one" do
      card.update!(design_config: {
        "version" => 1, "front" => { "photos" => { "photo_1" => { "blob_id" => blob.id } } }
      })

      expect(photo_image(render(card.reload)[:front])).to be_present
    end

    describe "the photo URL" do
      it "is absolute" do
        expect(photo_image(render(placed)[:front])["src"]).to start_with("http")
      end

      # The chosen approach: the public object URL, not a signed one. Production
      # serves uploads straight from a public GCS bucket, so there is no expiry
      # to outlive PostGrid's render, and the proof a user approves keeps
      # resolving for as long as the card exists.
      context "under the production CDN configuration" do
        around do |example|
          previous = [ Rails.configuration.x.cdn_enabled, Rails.configuration.x.cdn_host ]
          Rails.configuration.x.cdn_enabled = true
          Rails.configuration.x.cdn_host = "https://storage.googleapis.com/production-cardjoy-uploads"
          example.run
        ensure
          Rails.configuration.x.cdn_enabled, Rails.configuration.x.cdn_host = previous
        end

        it "is the public object URL, with no signature and no expiry" do
          src = photo_image(render(placed)[:front])["src"]

          expect(src).to eq("https://storage.googleapis.com/production-cardjoy-uploads/#{blob.key}")
          expect(URI.parse(src).query).to be_nil
        end
      end
    end
  end

  # --------------------------------------------------------------- the stickers

  describe "stickers" do
    def sticker_card(placements)
      new_card(template, { "version" => 1, "front" => { "stickers" => placements } })
    end

    it "embeds the sticker artwork rather than linking to it" do
      html = render(sticker_card([ { "region_id" => "corner_tl", "sticker_id" => "holly_sprig" } ]))[:front]

      # Read raw: a data URI contains the `;` that `declarations` splits on. It
      # is quoted, so a real CSS parser is untroubled by it.
      style = parse(html).at_css(".cj-sticker")["style"]
      encoded = Base64.strict_encode64(HolidayCardCatalogue.sticker("holly_sprig").svg)
      expect(style).to include("background-image:url('data:image/svg+xml;base64,#{encoded}')")
      expect(style).to include("background-size:contain")
    end

    it "accepts the older `region` key as well as `region_id`" do
      html = render(sticker_card([ { "region" => "corner_tl", "sticker_id" => "holly_sprig" } ]))[:front]

      expect(parse(html).at_css(".cj-sticker")["data-slot"]).to eq("corner_tl")
    end

    it "skips a sticker whose region the template does not have" do
      html = render(sticker_card([ { "region_id" => "nowhere", "sticker_id" => "holly_sprig" } ]))[:front]

      expect(parse(html).css(".cj-sticker")).to be_empty
    end

    it "skips a sticker the catalogue no longer ships" do
      html = render(sticker_card([ { "region_id" => "corner_tl", "sticker_id" => "retired_sticker" } ]))[:front]

      expect(parse(html).css(".cj-sticker")).to be_empty
    end
  end

  # ------------------------------------------------------------- half-built cards

  describe "a card that is not finished" do
    it "renders a freshly created card with an empty design config" do
      html = render(create(:holiday_card, size: template.size, template_id: template.id))

      expect(html[:front]).to include("<!DOCTYPE html>")
      expect(parse(html[:front]).css(".cj-photo").length).to eq(template.front.photo_slots.length)
      expect(parse(html[:front]).css(".cj-photo-image")).to be_empty
      expect(parse(html[:front]).css(".cj-text")).to be_empty
    end

    it "renders a card whose design config is nil" do
      card = create(:holiday_card, size: template.size, template_id: template.id)
      card.design_config = nil

      expect { render(card) }.not_to raise_error
    end

    it "ignores panels and slots the design config shapes wrongly" do
      card = create(:holiday_card, size: template.size, template_id: template.id)
      card.design_config = {
        "version" => 1,
        "front" => { "photos" => [], "texts" => "nope", "stickers" => { "not" => "a list" } }
      }

      expect { render(card) }.not_to raise_error
      expect(parse(render(card)[:front]).css(".cj-text")).to be_empty
    end
  end
end
