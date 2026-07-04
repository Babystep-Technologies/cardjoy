# typed: true

module Queries
  class AdminInvitations < Queries::BaseQuery
    type Types::PaginatedInvitationsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 25
    argument :search, String, required: false

    def resolve(page:, per_page:, search: nil)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Not authorized" unless admin

      invitations, total = ::Invitation.paginated(page: page, per_page: per_page, search: search)

      {
        invitations: invitations,
        total_count: total,
        current_page: page,
        per_page: per_page
      }
    end
  end
end
