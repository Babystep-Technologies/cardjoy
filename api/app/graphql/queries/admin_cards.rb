# typed: true

module Queries
  # The card list the admin dashboard moderates from (#177).
  #
  # `kind` is the argument that changed what this query is for: group cards and
  # 1-on-1 cards are two products in one table, and until this existed admin
  # could not separate them or even see which was which.
  #
  # Filters compose, so "flagged 1-on-1 cards this organization created this
  # month" is one request. The paging shape is unchanged — every admin query
  # uses `page` / `perPage` / `totalCount`.
  class AdminCards < Queries::BaseQuery
    type Types::PaginatedCardsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 25
    argument :search, String, required: false,
      description: "Matches title, external id, and the owner's name or email."
    argument :kind, String, required: false, description: "group or one_on_one."
    argument :status, String, required: false,
      description: "flagged, locked, archived, or active."
    argument :organization_id, ID, required: false
    argument :occasion, String, required: false
    argument :created_after, GraphQL::Types::ISO8601DateTime, required: false
    argument :created_before, GraphQL::Types::ISO8601DateTime, required: false
    argument :sort, String, required: false,
      description: "created_at, title, or message_count. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."

    def resolve(page:, per_page:, **filters)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Clamped here as well as inside `paginated`, so `perPage` in the payload
      # is the size the caller was actually served.
      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      cards, total = ::Card.paginated(page: page, per_page: per_page, **filters)

      {
        cards: cards,
        total_count: total,
        current_page: page,
        per_page: per_page
      }
    rescue ArgumentError => e
      # AdminListable rejects an unknown status, sort, or filter rather than
      # ignoring it, so a stale link says what is wrong with it.
      raise GraphQL::ExecutionError, e.message
    end
  end
end
