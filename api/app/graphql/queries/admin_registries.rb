# typed: true

module Queries
  # The registry list the admin dashboard reads from (#317). Standalone registries only; read-only,
  # because registries have no moderation columns. Same arguments as Queries::AdminInvitations.
  class AdminRegistries < Queries::BaseQuery
    type Types::PaginatedRegistriesType, null: false

    argument :page, Integer, required: false, default_value: 1
    argument :per_page, Integer, required: false, default_value: 25
    argument :search, String, required: false,
      description: "Matches title, external id, and the owner's name or email."
    argument :status, String, required: false, description: "Only `active` applies; registries have no moderation state."
    argument :occasion, String, required: false
    argument :sort, String, required: false,
      description: "created_at, title, or event_date. Defaults to created_at."
    argument :direction, String, required: false, description: "asc or desc. Defaults to desc."

    def resolve(page:, per_page:, **filters)
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless context[:current_admin]

      per_page = AdminListable.clamp_per_page(per_page)
      page = [ page.to_i, 1 ].max

      # T.unsafe: `paginated` comes from AdminListable's class_methods, which Sorbet can't see on a relation.
      registries, total = T.unsafe(::WishList.where(invitation_id: nil))
        .paginated(page: page, per_page: per_page, **filters)

      { registries: registries, total_count: total, current_page: page, per_page: per_page }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end
  end
end
