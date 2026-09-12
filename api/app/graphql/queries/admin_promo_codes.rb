# typed: true

module Queries
  class AdminPromoCodes < BaseQuery
    type Types::PaginatedPromoCodesType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false,
      description: "Matches the code and the assigned user's email."

    def resolve(page:, per_page:, search: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Limit per_page to prevent abuse. Clamped at both ends, because
      # `perPage: 0` divides by zero when the total pages are worked out.
      per_page = AdminListable.clamp_per_page(per_page)

      promo_codes = PromoCode.includes(:user).order(created_at: :desc)
      promo_codes = apply_search(promo_codes, search)

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
