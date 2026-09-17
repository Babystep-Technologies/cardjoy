# typed: true
# frozen_string_literal: true

module Types
  # One side of a post card. The back is the constrained one: PostGrid owns
  # the address block there, which is why the template exposes
  # `reservedAddressBlock` alongside these regions.
  class PostCardPanelType < Types::BaseObject
    field :name, String, null: false
    # `#rrggbb`, painted across the template's whole `bleedBox`.
    field :background, String, null: false
    field :photo_slots, [ Types::PostCardPhotoSlotType ], null: false
    field :text_regions, [ Types::PostCardTextRegionType ], null: false
    field :sticker_regions, [ Types::PostCardStickerRegionType ], null: false
  end
end
