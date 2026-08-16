# typed: true
# frozen_string_literal: true

module Types
  # Where a photo goes on a panel. `id` is what `design_config` keys its photo
  # placements by, so it is the join between the saved card and this geometry.
  class HolidayCardPhotoSlotType < Types::BaseObject
    field :id, String, null: false
    field :rect, Types::HolidayCardRectType, null: false
    # Corner radius in inches. 0 is a square corner.
    field :radius, Float, null: false
  end
end
