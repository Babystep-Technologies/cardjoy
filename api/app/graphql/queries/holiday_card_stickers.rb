# typed: true
# frozen_string_literal: true

module Queries
  # The sticker picker's catalogue. Like the templates, this is reference data
  # compiled into the release — no auth, no database.
  class HolidayCardStickers < BaseQuery
    type [ Types::HolidayCardStickerType ], null: false

    argument :category, String, required: false, description: "Filter to one category, e.g. \"snowflakes\"."

    def resolve(category: nil)
      HolidayCardCatalogue.stickers(category:)
    end
  end
end
