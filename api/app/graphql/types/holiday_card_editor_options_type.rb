# typed: true
# frozen_string_literal: true

module Types
  # Every constant the holiday card editor would otherwise have had to restate
  # in TypeScript.
  #
  # `holidayCardTemplates` already gives the editor the *geometry* it must not
  # duplicate. This is the same argument applied to the rest of the contract: the
  # font allow-list the model validates against, the type scale in points, the
  # zoom range, the text length cap. A client copy of any of them drifts, and
  # drift shows up either as a save the server rejects for a reason the user
  # can't see, or as a preview that doesn't match what prints.
  #
  # Read-only reference data compiled into the release, so — like the template
  # and sticker catalogues — this needs no auth and touches no database.
  class HolidayCardEditorOptionsType < Types::BaseObject
    # The design document shape this release writes. The editor stamps it into
    # `version` so it never has to guess.
    field :design_config_version, Integer, null: false
    # HolidayCard::VALID_SIZES — the paper the create flow may choose from.
    field :card_sizes, [ String ], null: false

    field :fonts, [ Types::HolidayCardFontType ], null: false
    field :text_sizes, [ Types::HolidayCardTextSizeType ], null: false
    field :alignments, [ String ], null: false
    # The multiplier the print renderer applies to every text region.
    field :line_height, Float, null: false
    field :text_max_length, Integer, null: false

    field :min_zoom, Float, null: false
    field :max_zoom, Float, null: false
    # How far a photo may be panned, as a fraction of its slot. The model does
    # not validate pan; the renderer clamps it, so the editor clamps to the same
    # number rather than silently having its value changed at print time.
    field :max_pan, Float, null: false
    field :max_photos, Integer, null: false

    def design_config_version = HolidayCard::CURRENT_DESIGN_CONFIG_VERSION
    def card_sizes = HolidayCard::VALID_SIZES

    # Ordered by VALID_FONTS rather than by the FACES hash, so the allow-list
    # stays the thing that decides what exists.
    def fonts
      HolidayCard::VALID_FONTS.filter_map { |key| HolidayCard::PrintFonts.face(key) }
    end

    def text_sizes
      HolidayCardCatalogue::TEXT_SIZES.filter_map do |key|
        points = HolidayCard::PrintRenderer::POINT_SIZES[key]
        { key:, points: points.to_f } if points
      end
    end

    def alignments = HolidayCardCatalogue::ALIGNMENTS
    def line_height = HolidayCard::PrintRenderer::LINE_HEIGHT
    def text_max_length = HolidayCard::TEXT_CONTENT_MAX_LENGTH

    def min_zoom = HolidayCard::MIN_ZOOM
    def max_zoom = HolidayCard::MAX_ZOOM
    def max_pan = HolidayCard::PrintRenderer::MAX_PAN
    def max_photos = HolidayCard::MAX_PHOTOS
  end
end
