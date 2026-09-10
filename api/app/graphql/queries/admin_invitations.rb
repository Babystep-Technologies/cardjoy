# typed: true

module Queries
  # The invitation list the admin dashboard moderates from (#177).
  #
  # The same arguments as Queries::AdminCards minus `kind` and the message-count
  # sort, which do not exist for invitations. `status` works here for the first
  # time: invitations only gained moderation columns in this change.
  class AdminInvitations < Queries::BaseQuery
    type Types::PaginatedInvitationsType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 25
    argument :search, String, required: false,
      description: "Matches title, external id, and the owner's name or email."
    argument :status, String, required: false,
      description: "flagged, locked, archived, or active."
    argument :organization_id, ID, required: false
    argument :created_after, GraphQL::Types::ISO8601DateTime, required: false
    argument :created_before, GraphQL::Types::ISO8601DateTime, required: false
    argument :sort, String, required: false,
      description: "created_at, title, event_date, or rsvp_count. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."

    def resolve(page:, per_page:, **filters)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Clamped here as well as inside `paginated`, so `perPage` in the payload
      # is the size the caller was actually served.
      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      invitations, total = ::Invitation.paginated(page: page, per_page: per_page, **filters)

      {
        invitations: invitations,
        total_count: total,
        current_page: page,
        per_page: per_page
      }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
