# typed: true

module Mutations
  # Promote a member to admin, or demote an admin back to member.
  #
  # Admin-gated: this is how an organization stops being hostage to whoever
  # happened to create it. The last-admin guard lives on OrganizationMembership,
  # so demoting the final admin comes back as a readable validation error.
  class UpdateOrganizationMembership < BaseMutation
    NOT_FOUND_ERROR = "Membership not found"

    argument :id, ID, required: true
    argument :role, String, required: true

    field :membership, Types::OrganizationMembershipType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, role:)
      user = context[:current_user]
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless user

      membership = OrganizationMembership.find_by(id: id)
      return failure([ NOT_FOUND_ERROR ]) unless membership

      # An archived organization reads as nil through the association, and
      # answering "not authorized" there is right: nobody administers it now.
      return failure([ NOT_AUTHORIZED_ERROR ]) unless org_admin?(membership.organization)
      return failure([ OrganizationMembership::INVALID_ROLE_ERROR ]) unless OrganizationMembership::ROLES.include?(role)

      return { membership:, errors: [] } if membership.update(role:)

      # The rejected role is still sitting on the in-memory record, so returning
      # it would show the client a change that did not happen.
      failure(membership.errors.full_messages)
    end

    private

    def failure(errors)
      { membership: nil, errors: errors }
    end
  end
end
