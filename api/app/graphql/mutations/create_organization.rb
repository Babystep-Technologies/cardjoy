# typed: true

module Mutations
  class CreateOrganization < BaseMutation
    argument :name, String, required: true
    argument :description, String, required: false

    field :organization, Types::OrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(name:, description: nil)
      user = context[:current_user]
      return { organization: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      # The creator is the organization's first admin — an org with no admin is
      # unmanageable, so both rows go in together or neither does.
      ApplicationRecord.transaction do
        organization = Organization.create!(name:, description:, created_by: user)
        organization.organization_memberships.create!(
          user: user,
          role: OrganizationMembership::ADMIN
        )

        { organization:, errors: [] }
      end
    rescue ActiveRecord::RecordInvalid => e
      { organization: nil, errors: e.record.errors.full_messages }
    end
  end
end
