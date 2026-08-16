# typed: true
# frozen_string_literal: true

module Types
  # A slot a sticker from `holidayCardStickers` can be dropped into. Sticker
  # regions may overlap photo slots — a corner flourish is meant to sit on top
  # of the picture.
  class HolidayCardStickerRegionType < Types::BaseObject
    field :id, String, null: false
    field :rect, Types::HolidayCardRectType, null: false
  end
end
