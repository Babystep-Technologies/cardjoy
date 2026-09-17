# typed: true
# frozen_string_literal: true

module Queries
  # The template picker's catalogue. Read-only reference data compiled into the
  # release, so it needs no auth and no database — see PostCardCatalogue.
  #
  # An unknown `size` returns an empty list rather than erroring: the argument
  # is a filter, and a client asking for a size we retired should see nothing
  # rather than a failed query.
  class PostCardTemplates < BaseQuery
    type [ Types::PostCardTemplateType ], null: false

    argument :size, String, required: false, description: "Filter to one of PostCard::VALID_SIZES, e.g. \"6x4\"."

    def resolve(size: nil)
      PostCardCatalogue.templates(size:)
    end
  end
end
