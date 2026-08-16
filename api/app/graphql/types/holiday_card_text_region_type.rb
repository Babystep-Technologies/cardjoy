# typed: true
# frozen_string_literal: true

module Types
  # Where text goes on a panel, and what it looks like until the user changes
  # it. The defaults are the template's design intent; `design_config` records
  # only what the user overrode.
  class HolidayCardTextRegionType < Types::BaseObject
    field :id, String, null: false
    field :rect, Types::HolidayCardRectType, null: false
    field :align, String, null: false
    field :default_font, String, null: false
    field :default_size, String, null: false
  end
end
