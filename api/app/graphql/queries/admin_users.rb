# typed: true

module Queries
  class AdminUsers < BaseQuery
    type Types::PaginatedUsersType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false

    def resolve(page:, per_page:, search: nil)
      # Limit per_page to prevent abuse. Clamped at both ends, because
      # `perPage: 0` divides by zero when the total pages are worked out.
      per_page = AdminListable.clamp_per_page(per_page)

      # Build the query
      users = ::User.order(created_at: :desc)

      # Apply search filter if provided. `sanitize_sql_like` so a name holding
      # `_` or `%` matches literally, the way it already does in the card and
      # invitation searches.
      if search.present?
        search_term = "%#{::User.sanitize_sql_like(search)}%"
        users = users.where(
          "email ILIKE ? OR name ILIKE ?",
          search_term,
          search_term
        )
      end

      # Calculate pagination
      total_count = users.count
      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      # Get paginated results
      paginated_users = users.limit(per_page).offset(offset)

      {
        users: paginated_users,
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    end
  end
end
