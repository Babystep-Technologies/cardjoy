# typed: true

module Mutations
  class UpdateOrganization < BaseMutation
    SLUG_BLANK_ERROR = "Slug can't be blank"
    SLUG_FORMAT_ERROR = "Slug may only contain lowercase letters, numbers, and hyphens"
    SLUG_LENGTH_ERROR = "Slug is too long (maximum is #{Organization::SLUG_MAX_LENGTH} characters)"
    SLUG_TAKEN_ERROR = "Slug has already been taken"

    argument :organization_id, ID, required: true
    argument :name, String, required: false
    argument :description, String, required: false

    # Renaming never touches the slug (see below), so changing it is its own
    # deliberate act — an admin who wants a new URL asks for one.
    argument :slug, String, required: false

    # Email branding (#123). Every one of these is optional and clearable: pass
    # an empty string to drop back to CardJoy's own branding for that field.
    argument :logo, ApolloUploadServer::Upload, required: false
    argument :accent_color, String, required: false
    argument :email_footer_text, String, required: false
    argument :email_reply_to, String, required: false

    field :organization, Types::OrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, name: nil, description: nil, slug: nil, logo: nil,
                accent_color: nil, email_footer_text: nil, email_reply_to: nil)
      user = context[:current_user]
      return { organization: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      organization = Organization.find_by(id: organization_id)
      return { organization: nil, errors: [ "Organization not found" ] } unless organization
      return { organization: nil, errors: [ NOT_AUTHORIZED_ERROR ] } unless org_admin?(organization)

      # The slug is deliberately left alone on rename — it is part of every link
      # already shared for this organization.
      # `unless nil?` rather than `if present?` throughout: an omitted argument
      # leaves the field alone, but an explicit empty string clears it, which is
      # how an admin drops a brand field back to the CardJoy default.
      attributes = {}
      attributes[:name] = name unless name.nil?
      attributes[:description] = description unless description.nil?
      attributes[:accent_color] = accent_color unless accent_color.nil?
      attributes[:email_footer_text] = email_footer_text unless email_footer_text.nil?
      attributes[:email_reply_to] = email_reply_to unless email_reply_to.nil?

      unless slug.nil?
        normalized = normalize_slug(slug)
        slug_error = slug_error_for(normalized, organization)
        return { organization: nil, errors: [ slug_error ] } if slug_error

        attributes[:slug] = normalized
      end

      organization.assign_attributes(attributes)
      organization.logo.attach(io: logo.to_io, filename: logo.original_filename) if logo

      if organization.save
        { organization:, errors: [] }
      else
        { organization: nil, errors: organization.errors.full_messages }
      end
    end

    private

    # Slugs are URLs, so a stray capital or a copied trailing space is a typo
    # rather than a different slug.
    def normalize_slug(slug)
      slug.to_s.strip.downcase
    end

    def slug_error_for(slug, organization)
      return SLUG_BLANK_ERROR if slug.blank?
      return SLUG_FORMAT_ERROR unless slug.match?(Organization::SLUG_FORMAT)
      return SLUG_LENGTH_ERROR if slug.length > Organization::SLUG_MAX_LENGTH
      # `unscoped`, matching Organization#assign_slug: an archived organization
      # still owns its slug through the unique index, and colliding with one
      # would raise past the model's uniqueness validation.
      return SLUG_TAKEN_ERROR if Organization.unscoped.where(slug:).where.not(id: organization.id).exists?

      nil
    end
  end
end
