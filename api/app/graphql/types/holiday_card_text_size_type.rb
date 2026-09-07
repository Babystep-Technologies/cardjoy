# typed: true
# frozen_string_literal: true

module Types
  # One step of the type scale, as both the name a design document stores and
  # the physical size it prints at.
  #
  # `points` is what makes the editor preview honest: a point is 1/72", so a
  # preview drawn at S pixels per inch renders this at `points / 72 * S` pixels
  # and matches the print exactly. Without it the client would have to hardcode
  # HolidayCard::PrintRenderer::POINT_SIZES and hope the two stayed in step.
  class HolidayCardTextSizeType < Types::BaseObject
    field :key, String, null: false
    field :points, Float, null: false
  end
end
