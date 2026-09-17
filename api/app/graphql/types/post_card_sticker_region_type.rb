# typed: true
# frozen_string_literal: true

module Types
  # A slot a sticker from `postCardStickers` can be dropped into. Sticker
  # regions may overlap photo slots — a corner flourish is meant to sit on top
  # of the picture.
  class PostCardStickerRegionType < Types::BaseObject
    field :id, String, null: false
    field :rect, Types::PostCardRectType, null: false
  end
end
