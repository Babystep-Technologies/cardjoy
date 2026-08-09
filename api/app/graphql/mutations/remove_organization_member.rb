# typed: true

module Mutations
  # Take someone out of an organization. Admin-gated — a member who wants out on
  # their own calls Mutations::LeaveOrganization instead.
  #
  # Destroying the membership is what revokes access: the after_destroy hook on
  # OrganizationMembership drops the removed user back to Personal if they were
  # acting in this organization.
  class RemoveOrganizationMember < BaseMutation
    NOT_FOUND_ERROR = "Membership not found"

    argument :id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(id:)
      user = context[:current_user]
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless user

      membership = OrganizationMembership.find_by(id: id)
      return failure([ NOT_FOUND_ERROR ]) unless membership

      # An archived organization reads as nil through the association, and
      # answering "not authorized" there is right: nobody administers it now.
      return failure([ NOT_AUTHORIZED_ERROR ]) unless org_admin?(membership.organization)

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
