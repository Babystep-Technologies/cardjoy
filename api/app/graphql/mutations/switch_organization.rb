# typed: true

module Mutations
  # Move the caller into one of their organizations, or back to Personal.
  #
  # Omitting organizationId (or passing null) means Personal, which is a real
  # context rather than "no change" — there is no other way to leave an
  # organization, so null cannot be treated as absent.
  class SwitchOrganization < BaseMutation
    argument :organization_id, ID, required: false

    field :user, Types::UserType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id: nil)
      user = context[:current_user]
      return { user: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      organization = nil

      if organization_id.present?
        organization = Organization.find_by(id: organization_id)

        # An unknown, archived, or simply-not-yours organization all answer the
        # same way. Distinguishing them would turn this into a probe for which
        # organization ids exist, and the caller can act on none of them.
        return { user: nil, errors: [ NOT_AUTHORIZED_ERROR ] } unless org_member?(organization)
      end

      if user.update(active_organization: organization)
        { user:, errors: [] }
      else
        { user: nil, errors: user.errors.full_messages }
      end
    end
  end
end
