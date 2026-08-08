# typed: true

module Mutations
  class DeleteOrganization < BaseMutation
    argument :organization_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(organization_id:)
      user = context[:current_user]
      return { success: false, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      organization = Organization.find_by(id: organization_id)
      return { success: false, errors: [ "Organization not found" ] } unless organization
      return { success: false, errors: [ NOT_AUTHORIZED_ERROR ] } unless org_admin?(organization)

      # Soft delete: memberships are kept so the organization stays restorable.
      organization.archive!
      { success: true, errors: [] }
    end
  end
end
