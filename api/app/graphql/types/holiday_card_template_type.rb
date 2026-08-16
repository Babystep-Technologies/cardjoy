# typed: true
# frozen_string_literal: true

module Types
  # A holiday card template: the geometry a `HolidayCard#design_config` fills in.
  #
  # Every measurement is in INCHES. The editor fetches this rather than mirroring
  # it in TypeScript, so there is exactly one source of truth for print geometry
  # — see HolidayCardCatalogue.
  class HolidayCardTemplateType < Types::BaseObject
    field :id, String, null: false
    field :name, String, null: false
    field :description, String, null: true
    # One of HolidayCard::VALID_SIZES, e.g. "6x4". Width first.
    field :size, String, null: false
    field :width_inches, Float, null: false
    field :height_inches, Float, null: false
    # How far the background prints past the trim line.
    field :bleed_inches, Float, null: false
    # How far in from the trim line content must stay.
    field :safe_margin_inches, Float, null: false
    # The box the background is painted across — the trimmed panel grown by the
    # bleed, so its origin is negative.
    field :bleed_box, Types::HolidayCardRectType, null: false
    # The box content must stay inside.
    field :safe_box, Types::HolidayCardRectType, null: false
    # The back-panel region PostGrid prints the address, indicia, and barcode
    # into. The editor must not let anything be dropped here, and no shipped
    # template overlaps it.
    field :reserved_address_block, Types::HolidayCardRectType, null: false
    field :front, Types::HolidayCardPanelType, null: false
    field :back, Types::HolidayCardPanelType, null: false

    def width_inches = object.width
    def height_inches = object.height
    def bleed_inches = HolidayCardCatalogue::BLEED
    def safe_margin_inches = HolidayCardCatalogue::SAFE_MARGIN
  end
end
