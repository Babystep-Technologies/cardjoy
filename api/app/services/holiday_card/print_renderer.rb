# typed: true
# frozen_string_literal: true

# Turns a saved holiday card into the two HTML documents PostGrid prints.
#
#   HolidayCard::PrintRenderer.new(card).render # => { front: "<!DOCTYPE...", back: "<!DOCTYPE..." }
#
# Two inputs meet here. `HolidayCardCatalogue` owns the *geometry* — where
# `photo_2` sits, in inches from the top-left of the trimmed panel.
# `HolidayCard#design_config` owns the *content* — which uploaded photo goes in
# that slot, and how it is panned and zoomed. Neither knows about the other, and
# this class is the only place they are combined.
#
# Design decisions (issue #143):
#
# * **HTML, not PDF.** PostGrid accepts `frontHTML`/`backHTML`, and rendering
#   HTML keeps the whole pipeline in Ruby — no headless-Chrome service in our
#   stack — while letting PostGrid's own renderer produce the proof the user
#   signs off on. What they render is what they print.
#
# * **Not coupled to PostGrid.** This takes a card and returns two strings. The
#   caller decides what to do with them, which keeps this testable with no HTTP
#   stubbing and leaves a PDF path open later.
#
# * **Inches, everywhere.** Catalogue coordinates are inches and reach the CSS
#   as `in`. A pixel value would bake in an assumed DPI, and PostGrid renders at
#   print resolution.
#
# * **Absolute positioning only.** Every slot is `position: absolute` at its
#   catalogue coordinates. No flexbox, no grid, no layout that depends on font
#   metrics — those are exactly where our renderer and PostGrid's would diverge.
#
# * **Everything is clipped.** Photo slots and text regions are `overflow:
#   hidden`, so a long greeting is cut off at its region boundary rather than
#   spilling across the card — and, on the back, rather than spilling into the
#   address block.
#
# * **Nothing is trusted.** Every value out of `design_config` is either escaped
#   (text) or checked against an allow-list (font, size, alignment, colour)
#   before it reaches the CSS. `design_config` is user input on a public app,
#   and this output goes to a third party.
#
# Every element carries a `cj-*` class and, where it has one, a `data-slot`.
# Nothing in the output styles off them — the styling is all inline, because
# PostGrid's renderer gets one document and no stylesheet to resolve. They exist
# so a rendered proof can be inspected, and so the spec can assert on slots by
# name rather than by position in the document.
#
# The pan/zoom CSS this emits is the contract the editor preview must reuse
# verbatim: the same `<img>` in the same `overflow: hidden` box under the same
# transform, at screen scale instead of print scale. Reimplementing the cropping
# maths in TypeScript is how the proof stops matching the print.
class HolidayCard::PrintRenderer
  # The card names a template that is no longer in the catalogue. Unlike a
  # missing photo or a blank slot this cannot be rendered around — there are no
  # coordinates to render *at* — so it raises. `HolidayCardCatalogue.template`
  # returns nil for a retired id, and the caller (a print job) is the right
  # place to decide what to tell the user.
  class UnknownTemplateError < StandardError; end

  BLEED = HolidayCardCatalogue::BLEED

  # The type scale, in points, for HolidayCardCatalogue::TEXT_SIZES. Points
  # because a point is a physical unit like an inch — 1pt = 1/72in — so this
  # stays resolution-independent for the same reason the positions do.
  POINT_SIZES = { "sm" => 9, "md" => 12, "lg" => 18, "xl" => 28 }.freeze

  LINE_HEIGHT = 1.3

  # A pan of 1.0 slides the photo a full slot-width across, which already puts
  # it entirely out of frame. `design_config` validates zoom but not pan, so the
  # ceiling is enforced here.
  MAX_PAN = 1.0

  # Used only when `design_config` gives a text no colour of its own. Picked
  # against the panel background so a template with a dark background
  # (#1F3A5F, #2E4A3D) does not render black text on it.
  LIGHT_TEXT = "#FFFFFF"
  DARK_TEXT = "#1A1A1A"

  def initialize(card)
    @card = card
    @template = HolidayCardCatalogue.template(card.template_id)
    raise UnknownTemplateError, "unknown holiday card template #{card.template_id.inspect}" unless @template
  end

  def render
    { front: render_panel(@template.front), back: render_panel(@template.back) }
  end

  private

  attr_reader :card, :template

  def render_panel(panel)
    config = panel_config(panel.name)

    # Paint order: photos, then stickers over them (the shipped corner stickers
    # deliberately overlap the photo beneath), then text on top of both.
    elements = photo_elements(panel, config) + sticker_elements(panel, config) + text_elements(panel, config)

    document(panel, elements.join("\n      "), fonts_used(panel, config))
  end

  # The design document, normalised. A card that has never been saved has no
  # panels at all, which renders as a blank template rather than raising.
  def panel_config(panel_name)
    document = card.design_config
    return {}.with_indifferent_access unless document.is_a?(Hash)

    panel = document.with_indifferent_access[panel_name]
    panel.is_a?(Hash) ? panel : {}.with_indifferent_access
  end

  # ---------------------------------------------------------------- elements

  def photo_elements(panel, config)
    placements = config[:photos]
    placements = {} unless placements.is_a?(Hash)

    panel.photo_slots.filter_map do |slot|
      next if reserved?(panel, slot.rect)

      box = box_style(slot.rect, radius: slot.radius)
      %(<div class="cj-photo" data-slot="#{escape(slot.id)}" style="#{box}">#{photo_image(placements[slot.id])}</div>)
    end
  end

  # The `<img>` inside a slot, or "" for a slot the user left empty — an empty
  # slot is a normal state of a half-finished card, not an error.
  def photo_image(placement)
    return "" unless placement.is_a?(Hash)

    blob = photo_blobs[placement[:blob_id].to_s]
    return "" unless blob

    style = "position:absolute;left:0;top:0;width:100%;height:100%;object-fit:cover;" \
            "transform:#{photo_transform(placement)};transform-origin:center center;"
    %(<img class="cj-photo-image" src="#{escape(card.photo_url(blob))}" alt="" style="#{style}">)
  end

  # Pan is a fraction of the slot's own width and height; zoom is a multiplier
  # on the cover-fitted image. Written translate-then-scale so the two are
  # independent: the percentages resolve against the *untransformed* slot box,
  # so panning by 0.1 always means "a tenth of a slot to the right", whatever
  # the zoom.
  def photo_transform(placement)
    zoom = numeric(placement[:zoom], default: 1.0).clamp(HolidayCard::MIN_ZOOM, HolidayCard::MAX_ZOOM)
    pan_x = numeric(placement[:pan_x], default: 0.0).clamp(-MAX_PAN, MAX_PAN)
    pan_y = numeric(placement[:pan_y], default: 0.0).clamp(-MAX_PAN, MAX_PAN)

    "translate(#{number(pan_x * 100)}%, #{number(pan_y * 100)}%) scale(#{number(zoom)})"
  end

  def text_elements(panel, config)
    placements = config[:texts]
    placements = {} unless placements.is_a?(Hash)

    panel.text_regions.filter_map do |region|
      next if reserved?(panel, region.rect)

      placement = placements[region.id]
      placement = {} unless placement.is_a?(Hash)
      content = placement[:content].to_s
      next if content.strip.empty?

      %(<div class="cj-text" data-slot="#{escape(region.id)}" style="#{text_style(panel, region, placement)}">#{formatted_text(content)}</div>)
    end
  end

  def text_style(panel, region, placement)
    font = allowed(placement[:font], HolidayCard::VALID_FONTS, region.default_font)
    size = allowed(placement[:size], HolidayCardCatalogue::TEXT_SIZES, region.default_size)
    align = allowed(placement[:align], HolidayCardCatalogue::ALIGNMENTS, region.align)
    color = hex_color(placement[:color]) || default_text_color(panel)

    "#{box_style(region.rect)}" \
      "font-family:#{HolidayCard::PrintFonts.font_stack(font)};" \
      "font-size:#{POINT_SIZES.fetch(size, POINT_SIZES.fetch('md'))}pt;" \
      "line-height:#{LINE_HEIGHT};" \
      "text-align:#{align};" \
      "color:#{color};" \
      "white-space:pre-wrap;word-wrap:break-word;"
  end

  # Newlines are the one bit of formatting a text slot carries, so they survive
  # as `<br>`. Everything else in the string is escaped: a greeting of
  # "<script>alert(1)</script>" has to print as those characters.
  def formatted_text(content)
    content.delete("\r").split("\n", -1).map { |line| escape(line) }.join("<br>")
  end

  def sticker_elements(panel, config)
    regions = panel.sticker_regions.index_by(&:id)

    Array(config[:stickers]).filter_map do |placement|
      next unless placement.is_a?(Hash)

      # `region_id` is the key the editor sends; `region` is accepted too
      # because it appears in already-written design documents and the model
      # never validated either.
      region = regions[(placement[:region_id] || placement[:region]).to_s]
      next unless region
      next if reserved?(panel, region.rect)

      sticker = HolidayCardCatalogue.sticker(placement[:sticker_id])
      next unless sticker

      style = "#{box_style(region.rect)}background-image:url('#{sticker.data_uri}');" \
              "background-repeat:no-repeat;background-position:center;background-size:contain;"
      %(<div class="cj-sticker" data-slot="#{escape(region.id)}" style="#{style}"></div>)
    end
  end

  # ---------------------------------------------------------------- geometry

  # Catalogue coordinates are measured from the top-left of the *trimmed* panel;
  # the document is the trim grown by the bleed on every side, so the origin
  # shifts by one bleed and every position with it.
  def box_style(rect, radius: nil)
    style = "position:absolute;overflow:hidden;" \
            "left:#{inches(rect.x + BLEED)};top:#{inches(rect.y + BLEED)};" \
            "width:#{inches(rect.w)};height:#{inches(rect.h)};"
    style += "border-radius:#{inches(radius)};" if radius.to_f.positive?
    style
  end

  # The back panel's right-hand block is PostGrid's: the recipient address, the
  # indicia, and the barcode clear zone. The catalogue already refuses to load a
  # template whose regions overlap it, so this never fires today — it is here so
  # that a future template with a bad rectangle loses a sticker rather than
  # getting the whole mailing rejected.
  def reserved?(panel, rect)
    panel.name == "back" && rect.overlaps?(template.reserved_address_block)
  end

  # ---------------------------------------------------------------- document

  def document(panel, body, fonts)
    width = template.width + (BLEED * 2)
    height = template.height + (BLEED * 2)
    background = hex_color(panel.background) || "#FFFFFF"

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <style>
            #{HolidayCard::PrintFonts.css(fonts)}
            @page { size: #{inches(width)} #{inches(height)}; margin: 0; }
            html, body { margin: 0; padding: 0; width: #{inches(width)}; height: #{inches(height)}; }
            /* Chromium drops background paint when printing unless told not to,
               and a card whose background did not print is a white card. */
            * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
          </style>
        </head>
        <body>
          <div class="cj-panel" data-panel="#{escape(panel.name)}" style="position:absolute;left:0;top:0;width:#{inches(width)};height:#{inches(height)};overflow:hidden;background-color:#{background};">
            #{body}
          </div>
        </body>
      </html>
    HTML
  end

  # The fonts this panel actually paints with — the whole point of collecting
  # them is that a card setting one Playfair greeting should not carry the other
  # five families' base64 as well.
  def fonts_used(panel, config)
    placements = config[:texts]
    placements = {} unless placements.is_a?(Hash)

    panel.text_regions.filter_map do |region|
      next if reserved?(panel, region.rect)

      placement = placements[region.id]
      placement = {} unless placement.is_a?(Hash)
      next if placement[:content].to_s.strip.empty?

      allowed(placement[:font], HolidayCard::VALID_FONTS, region.default_font)
    end.uniq
  end

  # ---------------------------------------------------------------- helpers

  # This card's own photos, by blob id as a string. Blob ids reach us through
  # GraphQL's `ID` scalar, so a round-tripped document may carry "42" where the
  # database holds 42; both name the same photo. Loaded once per render, and
  # this is the only database access the renderer makes — it issues no HTTP of
  # its own, by design.
  def photo_blobs
    @photo_blobs ||= card.photos.blobs.index_by { |blob| blob.id.to_s }
  end

  def default_text_color(panel)
    relative_luminance(hex_color(panel.background) || "#FFFFFF") < 0.5 ? LIGHT_TEXT : DARK_TEXT
  end

  # Good enough to answer "is this background dark?"; not a WCAG contrast
  # implementation, and it only ever picks between two fallbacks.
  def relative_luminance(hex)
    r, g, b = hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
    (0.299 * r) + (0.587 * g) + (0.114 * b)
  end

  def allowed(value, permitted, fallback)
    permitted.include?(value.to_s) ? value.to_s : fallback
  end

  def hex_color(value)
    value.to_s.match?(HolidayCard::HEX_COLOR_FORMAT) ? value.to_s : nil
  end

  def numeric(value, default:)
    value.is_a?(Numeric) ? value.to_f : default
  end

  def inches(value) = "#{number(value)}in"

  # Fixed precision, then trimmed: 0.375 stays "0.375" and 3.0 becomes "3", so
  # the output is both readable and exactly assertable in a spec. Four decimal
  # places is a ten-thousandth of an inch — far below what a printer resolves.
  def number(value)
    format("%.4f", value.to_f.round(4)).sub(/\.?0+\z/, "").presence || "0"
  end

  def escape(value) = CGI.escapeHTML(value.to_s)
end
