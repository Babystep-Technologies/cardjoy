# typed: true
# frozen_string_literal: true

# The webfonts the print renderer embeds, and the `@font-face` CSS that carries
# them.
#
# Design decision (issue #143): the font binaries are **vendored into this repo**
# and inlined as base64 rather than linked to a CDN. PostGrid renders our HTML on
# their infrastructure, and we cannot assume that renderer has network access to
# fonts.gstatic.com — a blocked request there silently falls back to a system
# face, which is not visible until a card has been printed and mailed. Bytes in
# the payload are the cheaper side of that trade.
#
# Each family ships two subsets, latin and latin-ext, with the same
# `unicode-range` split Fontsource publishes. latin-ext costs ~15KB per family
# and is what keeps a name like "Zoë Świątek" from falling back mid-word.
#
# Only weight 400 is vendored: nothing in `HolidayCard#design_config` expresses
# a weight, so a bold file could never be selected. Add one here (and a `weight`
# to the face) the day the design document grows a bold flag.
module HolidayCard::PrintFonts
  class MissingFontFileError < StandardError; end

  ASSET_DIR = Rails.root.join("app/assets/holiday_card_fonts")

  # Which characters each vendored subset covers. Copied verbatim from
  # Fontsource's generated CSS — the ranges are identical across all six
  # families, so they live here once instead of per face.
  SUBSETS = {
    "latin" => "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308," \
               "U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD",
    "latin-ext" => "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308," \
                   "U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0," \
                   "U+2113,U+2C60-2C7F,U+A720-A7FF"
  }.freeze

  WEIGHT = 400

  Face = Struct.new(:key, :name, :fallback, keyword_init: true) do
    # Deliberately prefixed rather than the bare family name. If PostGrid's
    # renderer happens to have a system "Poppins" installed, an unprefixed
    # `font-family: Poppins` could resolve to *their* copy at a different
    # version with different metrics. Nothing on the machine is called
    # "CardJoy Poppins" except the face we just embedded.
    def css_family = "CardJoy #{name}"

    # The generic fallback is the safety net for a glyph outside both vendored
    # subsets — a CJK character in a signoff renders in *something* rather than
    # in tofu.
    def font_stack = "'#{css_family}', #{fallback}"

    def files
      HolidayCard::PrintFonts::SUBSETS.keys.index_with do |subset|
        HolidayCard::PrintFonts::ASSET_DIR.join("#{key}-#{subset}-#{HolidayCard::PrintFonts::WEIGHT}.woff2")
      end
    end
  end

  # Keyed by the values HolidayCard::VALID_FONTS allows. A key here that is not
  # in VALID_FONTS is unreachable; a VALID_FONTS entry missing here would render
  # in the fallback face, so the spec asserts the two sets match exactly.
  FACES = {
    "poppins" => Face.new(key: "poppins", name: "Poppins", fallback: "sans-serif"),
    "playfair" => Face.new(key: "playfair", name: "Playfair Display", fallback: "serif"),
    "montserrat" => Face.new(key: "montserrat", name: "Montserrat", fallback: "sans-serif"),
    "dancing_script" => Face.new(key: "dancing_script", name: "Dancing Script", fallback: "cursive"),
    "cormorant" => Face.new(key: "cormorant", name: "Cormorant", fallback: "serif"),
    "libre_baskerville" => Face.new(key: "libre_baskerville", name: "Libre Baskerville", fallback: "serif")
  }.freeze

  class << self
    def face(key) = FACES[key.to_s]

    def font_stack(key)
      face = face(key)
      face ? face.font_stack : "serif"
    end

    # The `@font-face` blocks for exactly the fonts passed in, in a stable
    # order. Called with the fonts one panel actually uses, so a card that only
    # sets a Playfair greeting does not carry 240KB of Montserrat it never
    # renders.
    def css(keys)
      Array(keys).map(&:to_s).uniq.sort.filter_map { |key| face_css(key) }.join("\n")
    end

    # Test seam: drops the memoized base64, so a spec can prove the encoding is
    # read from disk rather than asserting against a warm cache.
    def reset!
      @face_css = nil
    end

    private

    # Memoized because base64-encoding ~240KB of woff2 on every render of every
    # card is pure waste — the files cannot change without a deploy. A torn read
    # here would at worst recompute an identical string, so this needs no lock.
    def face_css(key)
      @face_css ||= {}
      return @face_css[key] if @face_css.key?(key)

      face = face(key)
      return nil unless face

      @face_css[key] = face.files.map { |subset, path| font_face_rule(face, subset, path) }.join("\n")
    end

    def font_face_rule(face, subset, path)
      raise MissingFontFileError, "missing vendored font file #{path}" unless File.exist?(path)

      <<~CSS.strip
        @font-face {
          font-family: '#{face.css_family}';
          font-style: normal;
          font-weight: #{WEIGHT};
          font-display: block;
          src: url(data:font/woff2;base64,#{Base64.strict_encode64(File.binread(path))}) format('woff2');
          unicode-range: #{SUBSETS.fetch(subset)};
        }
      CSS
    end
  end
end
