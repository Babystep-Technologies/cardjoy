# typed: true

module Types
  class PaginatedSupportTicketsType < Types::BaseObject
    field :support_tickets, [ Types::SupportTicketType ], null: false
    field :total_count, Integer, null: false
    field :page, Integer, null: false
    field :per_page, Integer, null: false
    field :total_pages, Integer, null: false
  end
end
