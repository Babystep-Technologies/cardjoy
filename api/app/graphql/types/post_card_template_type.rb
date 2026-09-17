# typed: true
# frozen_string_literal: true

module Types
  # A post card template: the geometry a `PostCard#design_config` fills in.
  #
  # Every measurement is in INCHES. The editor fetches this rather than mirroring
  # it in TypeScript, so there is exactly one source of truth for print geometry
  # — see PostCardCatalogue.
  class PostCardTemplateType < Types::BaseObject
    field :id, String, null: false
    field :name, String, null: false
    field :description, String, null: true
    # One of PostCard::VALID_SIZES, e.g. "6x4". Width first.
    field :size, String, null: false
    field :width_inches, Float, null: false
    field :height_inches, Float, null: false
    # How far the background prints past the trim line.
    field :bleed_inches, Float, null: false
    # How far in from the trim line content must stay.
    field :safe_margin_inches, Float, null: false
    # The box the background is painted across — the trimmed panel grown by the
    # bleed, so its origin is negative.
    field :bleed_box, Types::PostCardRectType, null: false
    # The box content must stay inside.
    field :safe_box, Types::PostCardRectType, null: false
    # The back-panel region PostGrid prints the address, indicia, and barcode
    # into. The editor must not let anything be dropped here, and no shipped
    # template overlaps it.
    field :reserved_address_block, Types::PostCardRectType, null: false
    field :front, Types::PostCardPanelType, null: false
    field :back, Types::PostCardPanelType, null: false

    def width_inches = object.width
    def height_inches = object.height
    def bleed_inches = PostCardCatalogue::BLEED
    def safe_margin_inches = PostCardCatalogue::SAFE_MARGIN
  end
end
