# typed: true
# frozen_string_literal: true

module Queries
  # Every customer's holiday cards, for the admin dashboard (#178).
  #
  # Holiday cards had no admin surface at all — no page, no query, no metric —
  # while the product itself is substantial: soft delete, sizes, templates,
  # versioned design documents, up to 20 photos each. So an abuse report about
  # one had nowhere to land.
  #
  # Arguments mirror Queries::AdminCards, minus the ones holiday cards do not
  # have (`kind`, `organizationId`, `occasion`) and plus the two they do (`size`,
  # `templateId`). The implementation is AdminListable, same as cards and
  # invitations.
  class AdminHolidayCards < Queries::BaseQuery
    type Types::PaginatedHolidayCardsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 25
    argument :search, String, required: false,
      description: "Matches title, external id, and the owner's name or email."
    argument :status, String, required: false, description: "flagged, archived, or active."
    argument :size, String, required: false, description: "One of HolidayCard::VALID_SIZES."
    argument :template_id, String, required: false
    argument :created_after, GraphQL::Types::ISO8601DateTime, required: false
    argument :created_before, GraphQL::Types::ISO8601DateTime, required: false
    argument :sort, String, required: false,
      description: "created_at, title, or updated_at. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."

    def resolve(page:, per_page:, **filters)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      holiday_cards, total = ::HolidayCard.paginated(page: page, per_page: per_page, **filters)

      {
        holiday_cards: holiday_cards,
        total_count: total,
        current_page: page,
        per_page: per_page
      }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
