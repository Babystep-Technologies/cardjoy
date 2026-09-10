# typed: false
# frozen_string_literal: true

# The one search / filter / sort / paginate implementation behind every admin
# product list (#177). Card, Invitation, and HolidayCard include it, so the
# three lists in the admin dashboard answer the same arguments the same way and
# a new product gets a working admin list by declaring four class methods.
#
# Before this, each model carried its own `paginated` that did exactly
# `where("title ILIKE ?")` ordered by `created_at DESC`. That could not find a
# card by the `external_id` a customer pastes into a support ticket, could not
# list one customer's cards, and could not narrow to the flagged ones — which
# is the entire moderation workflow.
#
# Typed `false` like the other model concerns: everything here calls back into
# ActiveRecord methods that only exist on the including class.
module AdminListable
  extend ActiveSupport::Concern

  # Admin lists are staff-facing, but `perPage` still arrives from a browser, so
  # it is clamped the way Queries::AdminUsers already clamps it.
  MAX_PER_PAGE = 100

  # The moderation states a list can be narrowed to. `active` is the useful
  # inverse — the rows nobody has acted on — rather than a fourth flag.
  #
  # A model only offers the ones whose column it actually has; asking for a
  # status a product does not carry is an error rather than a silent no-op, so a
  # bad link says so instead of quietly showing everything.
  STATUSES = {
    "flagged" => :flagged_at,
    "locked" => :locked_at,
    "archived" => :deleted_at,
    "active" => nil
  }.freeze

  SORT_DIRECTIONS = %w[asc desc].freeze

  # The page size a request actually gets. A module function because the
  # resolvers have to report the same number they are served — a payload saying
  # `perPage: 9999` next to 100 rows is what the admin pager would then believe.
  def self.clamp_per_page(per_page)
    per_page.to_i.clamp(1, MAX_PER_PAGE)
  end

  class_methods do
    # Columns a `search` term matches on this model, besides the owner's name
    # and email. Both are always searched, because "find everything belonging to
    # this customer" is what support actually types.
    def admin_search_columns
      %w[title external_id]
    end

    # Sortable column name → the SQL that orders by it. Model-authored, never
    # caller-supplied: the key is what crosses the wire and the value is only
    # ever reached through this hash, which is what makes it safe to interpolate.
    def admin_sorts
      { "created_at" => "#{table_name}.created_at", "title" => "#{table_name}.title" }
    end

    # Equality filters this model accepts, e.g. `kind` on Card. Anything not
    # listed here is rejected rather than passed through to `where`.
    def admin_filters
      []
    end

    # Loaded for every row, because every admin list shows the owner and none of
    # them used to select it — 25 rows meant 26 queries the moment a column for
    # it appeared.
    def admin_preloads
      [ :user ]
    end

    def admin_statuses
      STATUSES.select { |_name, column| column.nil? || column_names.include?(column.to_s) }
    end

    # Returns `[rows, total_count]`, keeping the offset-pagination shape every
    # admin query already uses. Called with no optional argument it is the
    # previous behaviour: every row, newest first.
    #
    # Every argument has a default so a resolver can splat its GraphQL arguments
    # in one call — Sorbet refuses a keyword splat into a method with required
    # keywords, and the defaults here are the ones the resolvers declare anyway.
    def paginated(page: 1, per_page: 25, search: nil, status: nil, sort: nil, direction: nil,
                  created_after: nil, created_before: nil, **filters)
      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      scope = admin_status_scope(status)
      scope = admin_search_scope(scope, search)
      scope = admin_created_scope(scope, created_after, created_before)
      scope = admin_filter_scope(scope, filters)

      # Counted before the order and the preloads, so the total costs one plain
      # aggregate rather than materialising a page's worth of associations.
      total = scope.count

      rows = scope
        .order(admin_order(sort, direction))
        .offset((page - 1) * per_page)
        .limit(per_page)
        .preload(*admin_preloads)

      [ rows, total ]
    end

    private

    # `archived` is the only status that has to escape the model's own
    # `default_scope { where(deleted_at: nil) }` — without the unscope, asking
    # for archived rows returns nothing at all, which is what admin saw before
    # this existed.
    def admin_status_scope(status)
      return all if status.blank?

      column = admin_statuses.fetch(status) do
        raise ArgumentError, "Invalid status: #{status}"
      end

      case status
      when "archived"
        unscope(where: :deleted_at).where.not(deleted_at: nil)
      when "active"
        admin_statuses.values.compact.reduce(all) { |scope, col| scope.where(col => nil) }
      else
        where.not(column => nil)
      end
    end

    # Matches the model's own text columns or the owner's name or email. The
    # owner half is why this left-joins rather than filtering in Ruby: the
    # matching rows have to be countable and pageable in one query.
    def admin_search_scope(scope, search)
      return scope if search.blank?

      term = "%#{sanitize_sql_like(search.to_s.strip)}%"
      own = admin_search_columns.map { |column| "#{table_name}.#{column} ILIKE :term" }
      owner = [ "users.name ILIKE :term", "users.email ILIKE :term" ]

      scope.left_joins(:user).where((own + owner).join(" OR "), term: term)
    end

    # Half-open on purpose: `createdBefore` is exclusive, so a month picked as
    # the 1st to the 1st cannot double-count a row on the boundary.
    def admin_created_scope(scope, created_after, created_before)
      scope = scope.where("#{table_name}.created_at >= ?", created_after) if created_after.present?
      scope = scope.where("#{table_name}.created_at < ?", created_before) if created_before.present?
      scope
    end

    def admin_filter_scope(scope, filters)
      filters.each do |name, value|
        next if value.blank?
        unless admin_filters.include?(name.to_s)
          raise ArgumentError, "Invalid filter: #{name}"
        end

        scope = scope.where(name => value)
      end
      scope
    end

    # Ties break on `id` so a row cannot appear on two pages, or on neither,
    # when a batch of rows shares a `created_at` to the microsecond.
    def admin_order(sort, direction)
      sort = sort.presence || "created_at"
      direction = (direction.presence || "desc").to_s.downcase

      column = admin_sorts.fetch(sort) { raise ArgumentError, "Invalid sort: #{sort}" }
      unless SORT_DIRECTIONS.include?(direction)
        raise ArgumentError, "Invalid sort direction: #{direction}"
      end

      Arel.sql("#{column} #{direction.upcase}, #{table_name}.id DESC")
    end
  end
end
