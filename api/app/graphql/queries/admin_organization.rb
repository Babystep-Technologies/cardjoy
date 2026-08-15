# typed: true

module Queries
  # One organization in full for internal support (#130): the roster with roles
  # and each member's personal balance, plus the shared pool's ledger.
  #
  # Null for an id that doesn't exist and for an archived organization, which
  # Organization's default scope hides — the list excludes those too, so the
  # detail view stays consistent with the page staff arrived from.
  class AdminOrganization < BaseQuery
    type Types::AdminOrganizationType, null: true

    argument :id, ID, required: true

    def resolve(id:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      ::Organization.find_by(id: id)
    end
  end
end
