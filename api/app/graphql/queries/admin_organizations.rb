# typed: true

module Queries
  # The organizations list internal support works from (#130): who exists, how
  # big they are, and what their shared pool holds.
  #
  # Read-only. Per the epic's locked decision staff do not create organizations
  # or edit customer memberships; the one write they get is
  # Mutations::GrantOrganizationCredits (and, for a pool correction,
  # Mutations::AdjustOrganizationCredits).
  class AdminOrganizations < BaseQuery
    type Types::PaginatedOrganizationsType, null: false

    # `members_count`/`credit_balance` sort by a joined aggregate rather than a
    # plain column, so they are handled separately in #apply_sort.
    SORTS = %w[name members_count credit_balance created_at].freeze

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false
    argument :sort, String, required: false,
      description: "name, members_count, credit_balance, or created_at. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."
    argument :include_archived, Boolean, required: false,
      description: "Include organizations deleteOrganization has archived. Defaults to false."

    def resolve(page:, per_page:, search: nil, sort: nil, direction: nil, include_archived: false)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Limit per_page to prevent abuse. Clamped at both ends, because
      # `perPage: 0` divides by zero when the total pages are worked out.
      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      # Archived organizations are excluded by Organization's default scope
      # unless asked for — deleteOrganization is a soft delete, and until now
      # there was no way to reach one from the admin dashboard at all.
      organizations = include_archived ? ::Organization.unscoped : ::Organization.all
      organizations = apply_search(organizations, search)

      # Counted before the sort join, so the total costs one plain aggregate
      # rather than a grouped query.
      total_count = organizations.count
      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      {
        organizations: apply_sort(organizations, sort, direction).limit(per_page).offset(offset),
        total_count: total_count,
        page: page,
        per_page: per_page,
        total_pages: total_pages
      }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end

    private

    # `sanitize_sql_like` so an organization name holding `_` or `%` matches
    # literally, the way it already does in the card and invitation searches.
    def apply_search(scope, search)
      return scope if search.blank?

      term = "%#{::Organization.sanitize_sql_like(search)}%"
      scope.where("organizations.name ILIKE ? OR organizations.slug ILIKE ?", term, term)
    end

    # `members_count` and `credit_balance` have no column to order by, so those
    # two join and group; every other sort is a plain column order. Ties break
    # on id, matching AdminListable#admin_order, so a batch of organizations
    # sharing a value can't land on two pages.
    def apply_sort(scope, sort, direction)
      sort = sort.presence || "created_at"
      direction = (direction.presence || "desc").to_s.downcase

      raise ArgumentError, "Invalid sort: #{sort}" unless SORTS.include?(sort)
      unless AdminListable::SORT_DIRECTIONS.include?(direction)
        raise ArgumentError, "Invalid sort direction: #{direction}"
      end

      dir = direction.upcase
      case sort
      when "members_count"
        scope.left_joins(:organization_memberships)
          .group("organizations.id")
          .order(Arel.sql("COUNT(organization_memberships.id) #{dir}, organizations.id DESC"))
      when "credit_balance"
        scope.left_joins(:organization_credits)
          .group("organizations.id")
          .order(Arel.sql("COALESCE(SUM(organization_credits.amount), 0) #{dir}, organizations.id DESC"))
      else
        scope.order(Arel.sql("organizations.#{sort} #{dir}, organizations.id DESC"))
      end
    end
  end
end
