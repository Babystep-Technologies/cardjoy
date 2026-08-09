# typed: true

module Mutations
  # Leave an organization you belong to. The one membership mutation that is not
  # admin-gated: it only ever acts on the caller's own membership.
  #
  # The last admin still cannot leave — an organization nobody can administer is
  # worse for the people left in it than a departure that has to be handed off
  # first.
  class LeaveOrganization < BaseMutation
    argument :organization_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(organization_id:)
      user = context[:current_user]
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless user

      # Unknown, archived, and not-yours organizations all answer the same way;
      # the caller can act on none of them.
      organization = Organization.find_by(id: organization_id)
      membership = current_membership(organization)
      return failure([ NOT_AUTHORIZED_ERROR ]) unless membership

      # Blocked by the last-admin guard, which aborts the destroy and leaves its
      # reason on the record.
      return failure(membership.errors.full_messages) unless membership.destroy

      { success: true, errors: [] }
    end

    private

    def failure(errors)
      { success: false, errors: errors }
    end
  end
end
