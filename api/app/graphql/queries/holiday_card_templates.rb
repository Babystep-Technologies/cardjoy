# typed: true
# frozen_string_literal: true

module Queries
  # The template picker's catalogue. Read-only reference data compiled into the
  # release, so it needs no auth and no database — see HolidayCardCatalogue.
  #
  # An unknown `size` returns an empty list rather than erroring: the argument
  # is a filter, and a client asking for a size we retired should see nothing
  # rather than a failed query.
  class HolidayCardTemplates < BaseQuery
    type [ Types::HolidayCardTemplateType ], null: false

    argument :size, String, required: false, description: "Filter to one of HolidayCard::VALID_SIZES, e.g. \"6x4\"."

    def resolve(size: nil)
      HolidayCardCatalogue.templates(size:)
    end
  end
end
