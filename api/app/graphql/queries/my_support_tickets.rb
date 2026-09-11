# typed: true

module Queries
  # The caller's own support tickets, newest first (#172).
  class MySupportTickets < BaseQuery
    type Types::PaginatedSupportTicketsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 20
    argument :status, String, required: false

    def resolve(page:, per_page:, status: nil)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      # Clamped at both ends the way Queries::AdminUsers clamps it — `perPage:
      # 0` divides by zero when total_pages is worked out.
      per_page = AdminListable.clamp_per_page(per_page)

      tickets = user.support_tickets.order(created_at: :desc)

      if status.present?
        # ::SupportTicket, not SupportTicket: inside the Queries module this
        # would otherwise resolve to Queries::SupportTicket, the query class
        # below, which has no STATUSES constant.
        unless ::SupportTicket::STATUSES.include?(status)
          raise GraphQL::ExecutionError, "Invalid status"
        end
        tickets = tickets.where(status:)
      end

      total_count = tickets.count
      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      {
        support_tickets: tickets.limit(per_page).offset(offset),
        total_count:,
        page:,
        per_page:,
        total_pages:
      }
    end
  end
end
