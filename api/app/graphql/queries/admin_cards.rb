# typed: true

module Queries
  class AdminCards < Queries::BaseQuery
    type Types::PaginatedCardsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 25
    argument :search, String, required: false

    def resolve(page:, per_page:, search: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin

      cards, total = ::Card.paginated(page: page, per_page: per_page, search: search)

      {
        cards: cards,
        total_count: total,
        current_page: page,
        per_page: per_page
      }
    end
  end
end
