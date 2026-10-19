# typed: true

module Queries
  class AdminPromoCodes < BaseQuery
    type Types::PaginatedPromoCodesType, null: false

    SORTS = {
      "created_at" => "promo_codes.created_at",
      "code" => "promo_codes.code",
      "credit_amount" => "promo_codes.credit_amount",
      "times_redeemed" => "promo_codes.times_redeemed",
      "expires_at" => "promo_codes.expires_at"
    }.freeze

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false,
      description: "Matches the code and the assigned user's email."

    argument :status, String, required: false,
      description: "active, expired, disabled, or fully_redeemed."
    argument :sort, String, required: false,
      description: "created_at, code, credit_amount, times_redeemed, or expires_at. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."

    def resolve(page:, per_page:, search: nil, status: nil, sort: nil, direction: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Limit per_page to prevent abuse. Clamped at both ends, because
      # `perPage: 0` divides by zero when the total pages are worked out.
      per_page = AdminListable.clamp_per_page(per_page)

      promo_codes = PromoCode.includes(:user)
      promo_codes = apply_status(promo_codes, status)
      promo_codes = apply_search(promo_codes, search)
      promo_codes = promo_codes.order(order_clause(sort, direction))

      total_count = promo_codes.count
      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      {
        promo_codes: promo_codes.limit(per_page).offset(offset),
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    end

    private

    def apply_status(scope, status)
      return scope if status.blank?
      raise GraphQL::ExecutionError, "Invalid status: #{status}" unless PromoCode::STATUSES.include?(status)

      scope.with_status(status)
    end

    # Both halves come out of allowlists, so neither is caller-controlled SQL.
    # `id` breaks ties so paging through equal values stays stable, and NULLS
    # LAST keeps never-expiring codes from crowding the top of an expiry sort.
    def order_clause(sort, direction)
      column = SORTS[sort.presence || "created_at"]
      raise GraphQL::ExecutionError, "Invalid sort: #{sort}" unless column

      dir = (direction.presence || "desc").downcase
      raise GraphQL::ExecutionError, "Invalid direction: #{direction}" unless AdminListable::SORT_DIRECTIONS.include?(dir)

      Arel.sql("#{column} #{dir.upcase} NULLS LAST, promo_codes.id #{dir.upcase}")
    end

    # A left join, not `.where(user: ...)`, so a general code (no assigned
    # user) still matches on its own `code` rather than being excluded by the
    # join.
    def apply_search(scope, search)
      return scope if search.blank?

      term = "%#{PromoCode.sanitize_sql_like(search.to_s.strip)}%"
      scope.left_joins(:user).where("promo_codes.code ILIKE :term OR users.email ILIKE :term", term: term)
    end
  end
end
