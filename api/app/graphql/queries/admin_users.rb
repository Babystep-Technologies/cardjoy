# typed: true

module Queries
  class AdminUsers < BaseQuery
    type Types::PaginatedUsersType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false

    def resolve(page:, per_page:, search: nil)
      # Limit per_page to prevent abuse
      per_page = [ per_page, 100 ].min

      # Build the query
      users = ::User.order(created_at: :desc)

      # Apply search filter if provided
      if search.present?
        search_term = "%#{search}%"
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
