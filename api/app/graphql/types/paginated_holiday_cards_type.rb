# typed: true
# frozen_string_literal: true

module Types
  # The same offset-pagination shape as Types::PaginatedCardsType, so the admin
  # dashboard pages all three product lists with one component.
  class PaginatedHolidayCardsType < Types::BaseObject
    field :holiday_cards, [ Types::HolidayCardType ], null: false
    field :total_count, Integer, null: false
    field :current_page, Integer, null: false
    field :per_page, Integer, null: false
  end
end
