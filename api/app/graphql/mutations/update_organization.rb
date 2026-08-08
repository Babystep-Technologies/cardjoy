# typed: true

module Mutations
  class UpdateOrganization < BaseMutation
    argument :organization_id, ID, required: true
    argument :name, String, required: false
    argument :description, String, required: false

    field :organization, Types::OrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, name: nil, description: nil)
      user = context[:current_user]
      return { organization: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      organization = Organization.find_by(id: organization_id)
      return { organization: nil, errors: [ "Organization not found" ] } unless organization
      return { organization: nil, errors: [ NOT_AUTHORIZED_ERROR ] } unless org_admin?(organization)

      # The slug is deliberately left alone on rename — it is part of every link
      # already shared for this organization.
      attributes = {}
      attributes[:name] = name unless name.nil?
      attributes[:description] = description unless description.nil?

      if organization.update(attributes)
        { organization:, errors: [] }
      else
        { organization: nil, errors: organization.errors.full_messages }
      end
    end
  end
end
