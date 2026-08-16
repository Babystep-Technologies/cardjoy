# typed: true
# frozen_string_literal: true

module Types
  # A rectangle in INCHES, measured from the top-left of the trimmed panel. The
  # client multiplies by whatever DPI it is rendering at; the print renderer
  # does the same with the print DPI, so both agree by construction.
  class HolidayCardRectType < Types::BaseObject
    field :x, Float, null: false
    field :y, Float, null: false
    field :w, Float, null: false
    field :h, Float, null: false
  end
end
