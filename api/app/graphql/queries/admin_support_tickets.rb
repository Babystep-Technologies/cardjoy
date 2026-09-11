# typed: true

module Queries
  # The admin support inbox list (#173): every open ticket nobody has replied
  # to floats to the top by default, so staff always sees the oldest
  # unanswered conversation first without having to ask for it.
  class AdminSupportTickets < BaseQuery
    type Types::PaginatedSupportTicketsType, null: false

    SORTS = {
      "created_at_asc" => "support_tickets.created_at ASC",
      "created_at_desc" => "support_tickets.created_at DESC",
      "last_customer_reply_at_asc" => "support_tickets.last_customer_reply_at ASC",
      "last_customer_reply_at_desc" => "support_tickets.last_customer_reply_at DESC"
    }.freeze

    # Oldest ticket still awaiting a staff reply first: open tickets before
    # everything else, then by how long the customer has been waiting.
    DEFAULT_ORDER = Arel.sql("(support_tickets.status = 'open') DESC, support_tickets.last_customer_reply_at ASC").freeze

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :search, String, required: false,
      description: "Matches the ticket subject, message bodies, and the customer's name or email."
    argument :status, String, required: false, description: "open, pending, resolved, or closed."
    argument :category, String, required: false
    argument :assigned_admin_id, ID, required: false
    argument :sort, String, required: false,
      description: "created_at_asc, created_at_desc, last_customer_reply_at_asc, or " \
        "last_customer_reply_at_desc. Defaults to the oldest unanswered ticket first."

    def resolve(page:, per_page:, search: nil, status: nil, category: nil, assigned_admin_id: nil, sort: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      tickets = ::SupportTicket.all
      tickets = filter_status(tickets, status)
      tickets = filter_category(tickets, category)
      tickets = filter_assigned_admin(tickets, assigned_admin_id)
      tickets = search_scope(tickets, search)

      total_count = tickets.count
      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      {
        support_tickets: tickets
          .order(order_clause(sort))
          .offset(offset)
          .limit(per_page)
          .preload(:user, :assigned_admin, :status_updated_by_admin),
        total_count:,
        page:,
        per_page:,
        total_pages:
      }
    end

    private

    def filter_status(tickets, status)
      return tickets if status.blank?

      unless ::SupportTicket::STATUSES.include?(status)
        raise GraphQL::ExecutionError, "Invalid status: #{status}"
      end

      tickets.where(status:)
    end

    def filter_category(tickets, category)
      return tickets if category.blank?

      unless ::SupportTicket::CATEGORIES.include?(category)
        raise GraphQL::ExecutionError, "Invalid category: #{category}"
      end

      tickets.where(category:)
    end

    def filter_assigned_admin(tickets, assigned_admin_id)
      return tickets if assigned_admin_id.blank?

      tickets.where(assigned_admin_id:)
    end

    # A subquery of matching ids rather than a join directly on `tickets`: a
    # ticket with several messages matching `search` would otherwise join to
    # more than one row, and Postgres won't allow a `SELECT DISTINCT` next to
    # an `ORDER BY` expression that isn't in the select list — which the
    # custom default ordering below always is.
    def search_scope(tickets, search)
      return tickets if search.blank?

      term = "%#{::SupportTicket.sanitize_sql_like(search.to_s.strip)}%"
      matching_ids = ::SupportTicket
        .left_joins(:user, :messages)
        .where(
          "support_tickets.subject ILIKE :term OR support_ticket_messages.body ILIKE :term " \
            "OR users.name ILIKE :term OR users.email ILIKE :term",
          term:
        )
        .select(:id)

      tickets.where(id: matching_ids)
    end

    def order_clause(sort)
      return DEFAULT_ORDER if sort.blank?

      SORTS.fetch(sort) { raise GraphQL::ExecutionError, "Invalid sort: #{sort}" }
    end
  end
end
