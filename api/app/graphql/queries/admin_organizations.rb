# typed: true

module Queries
  # The organizations list internal support works from (#130): who exists, how
  # big they are, and what their shared pool holds.
  #
  # Read-only. Per the epic's locked decision staff do not create organizations
  # or edit customer memberships; the one write they get is
  # Mutations::GrantOrganizationCredits.
  class AdminOrganizations < BaseQuery
    type Types::PaginatedOrganizationsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false

    def resolve(page:, per_page:, search: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Limit per_page to prevent abuse. Clamped at both ends, because
      # `perPage: 0` divides by zero when the total pages are worked out.
      per_page = AdminListable.clamp_per_page(per_page)

      # Archived organizations are excluded, by Organization's default scope:
      # deleteOrganization is a soft delete, and a deleted customer account is
      # not something support acts on.
      organizations = ::Organization.order(created_at: :desc)

      # `sanitize_sql_like` so an organization name holding `_` or `%` matches
      # literally, the way it already does in the card and invitation searches.
      if search.present?
        search_term = "%#{::Organization.sanitize_sql_like(search)}%"
        organizations = organizations.where("name ILIKE ? OR slug ILIKE ?", search_term, search_term)
      end

      total_count = organizations.count
      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      {
        organizations: organizations.limit(per_page).offset(offset),
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    end
  end
end
