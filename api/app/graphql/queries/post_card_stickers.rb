# typed: true
# frozen_string_literal: true

module Queries
  # The sticker picker's catalogue. Like the templates, this is reference data
  # compiled into the release — no auth, no database.
  class PostCardStickers < BaseQuery
    type [ Types::PostCardStickerType ], null: false

    argument :category, String, required: false, description: "Filter to one category, e.g. \"snowflakes\"."

    def resolve(category: nil)
      PostCardCatalogue.stickers(category:)
    end
  end
end
