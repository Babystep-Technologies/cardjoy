# typed: true
# frozen_string_literal: true

module Types
  # A standardized design element a card can drop into a template's sticker
  # region.
  #
  # The artwork crosses the wire as a data URI rather than a URL: the API is
  # API-only with no asset pipeline to serve it from, and the print renderer
  # needs it embedded anyway. `<img src={dataUri} />` in the editor and a base64
  # embed at print time are then the same bytes.
  class HolidayCardStickerType < Types::BaseObject
    field :id, String, null: false
    field :name, String, null: false
    field :category, String, null: false
    field :data_uri, String, null: false
  end
end
