# typed: true
# frozen_string_literal: true

module Queries
  class BaseQuery < GraphQL::Schema::Resolver
    NOT_AUTHORIZED_ERROR = "Not authorized"

    # Mirrors Mutations::BaseMutation::NOT_AUTHENTICATED_ERROR. The controller
    # already rejects anonymous callers for every non-public operation, so this
    # is the backstop for a query smuggled into an operation *named* like a
    # public one (GraphqlController::PUBLIC_OPERATIONS matches on the name).
    NOT_AUTHENTICATED_ERROR = "Not authenticated"

    private

    # The organization a context-aware read should run in, resolved from its
    # optional `organizationId` argument. Mirrors
    # Mutations::BaseMutation#writable_organization: nil means Personal, `false`
    # means the caller may not read there.
    #
    # An unknown id is denied rather than reported as not-found, so a stranger
    # can't probe which organization ids exist. Any member may read, so this is
    # a membership check rather than an admin one.
    def readable_organization(organization_id)
      return nil if organization_id.blank?

      organization = Organization.find_by(id: organization_id)
      return false unless organization&.membership_for(context[:current_user])

      organization
    end
  end
end
