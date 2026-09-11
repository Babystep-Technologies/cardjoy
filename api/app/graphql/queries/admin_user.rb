# typed: true

module Queries
  # One user in full for internal support (#180): the profile, credit history,
  # and what they've made — the page a ticket or the users list drills into.
  #
  # Null for an id that doesn't exist, matching Queries::AdminOrganization.
  class AdminUser < BaseQuery
    type Types::AdminUserType, null: true

    argument :id, ID, required: true

    def resolve(id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ::User.find_by(id: id)
    end
  end
end
