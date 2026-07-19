# typed: true

module Queries
  class AdminPromoCodes < BaseQuery
    type Types::PaginatedPromoCodesType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20

    def resolve(page:, per_page:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin

      # Limit per_page to prevent abuse
      per_page = [ per_page, 100 ].min

      promo_codes = PromoCode.includes(:user).order(created_at: :desc)

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
  end
end
