# typed: true

module Queries
  # The credits & promos list the admin dashboard manages from (#180).
  #
  # `search` matches the code and the assigned user's email; `status` narrows to
  # one of PromoCode::STATUSES. Both are computed by PromoCode.admin_list rather
  # than AdminListable — a promo's status comes from three columns, not one, and
  # its search columns are not a product's title/external_id.
  class AdminPromoCodes < BaseQuery
    type Types::PaginatedPromoCodesType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false,
      description: "Matches the code or the assigned user's email."
    argument :status, String, required: false,
      description: "disabled, expired, fully_redeemed, or active."
    argument :sort, String, required: false,
      description: "code, credit_amount, times_redeemed, expires_at, or created_at. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."

    def resolve(page:, per_page:, search: nil, status: nil, sort: nil, direction: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Clamped here as well as inside `admin_list`, so `perPage` in the payload
      # is the size the caller was actually served.
      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      promo_codes, total_count = PromoCode.admin_list(
        page: page, per_page: per_page, search: search, status: status, sort: sort, direction: direction
      )
      total_pages = (total_count.to_f / per_page).ceil

      {
        promo_codes: promo_codes,
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    rescue ArgumentError => e
      # PromoCode.admin_list rejects an unknown status, sort, or direction
      # rather than ignoring it, so a stale link says what is wrong with it.
      raise GraphQL::ExecutionError, e.message
    end
  end
end
