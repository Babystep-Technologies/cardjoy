# typed: true
# frozen_string_literal: true

module Types
  # One font a holiday card's text may be set in.
  #
  # `key` is the value that goes into `design_config` and the only one the model
  # validates against HolidayCard::VALID_FONTS. `name` and `fallback` are here so
  # the editor can label the option and build a matching CSS stack instead of
  # keeping its own copy of the mapping — the same reason the geometry is
  # fetched rather than mirrored.
  class HolidayCardFontType < Types::BaseObject
    field :key, String, null: false
    # The family as the print renderer names it, e.g. "Playfair Display".
    field :name, String, null: false
    # The generic family the print renderer falls back to, e.g. "serif".
    field :fallback, String, null: false
  end
end
