# typed: true

module Queries
  class Tags < BaseQuery
    type [ Types::TagType ], null: true

    def resolve
      ::Tag.all
    end
  end
end
