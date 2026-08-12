# typed: true

module Mutations
  # Upload a design asset that belongs to one organization (#124).
  #
  # The asset is an ordinary Style with `organization_id` set, so it flows
  # through the cover picker, `#value`, and soft delete exactly like a curated
  # one — it is just only visible to this organization (Style.available_to).
  #
  # Admin-gated: any member may use the org's artwork, only an admin may add to
  # it.
  class CreateOrganizationStyle < BaseMutation
    NOT_FOUND_ERROR = "Organization not found"

    DEFAULT_KIND = "cover"

    argument :organization_id, ID, required: true
    argument :image, ApolloUploadServer::Upload, required: true
    argument :name, String, required: false
    argument :kind, String, required: false

    field :style, Types::StyleType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, image:, name: nil, kind: nil)
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless context[:current_user]

      organization = Organization.find_by(id: organization_id)
      return failure([ NOT_FOUND_ERROR ]) unless organization

      # "Not authorized" for a plain member and a non-member alike, so a
      # stranger can't learn which organization ids exist.
      return failure([ NOT_AUTHORIZED_ERROR ]) unless org_admin?(organization)

      style = build_style(organization:, image:, name:, kind:)
      return failure(style.errors.full_messages) unless style.persisted?

      { style:, errors: [] }
    rescue => e
      failure([ e.message ])
    end

    private

    def build_style(organization:, image:, name:, kind:)
      # Copy the upload to a temporary file before attaching, mirroring
      # Mutations::CreateCoverStyle: the request's own tempfile can be reaped
      # before Active Storage finishes reading it.
      buffered_file = Tempfile.new([ "upload", File.extname(image.original_filename) ])
      buffered_file.binmode
      buffered_file.write(image.read)
      buffered_file.rewind

      style = Style.new(
        organization:,
        kind: kind.presence || DEFAULT_KIND,
        source: nil, # the attachment is the source of truth for uploads
        name: name.presence || image.original_filename
      )
      style.image.attach(io: buffered_file, filename: image.original_filename)
      style.save
      style
    ensure
      buffered_file&.close
      buffered_file&.unlink
    end

    def failure(errors)
      { style: nil, errors: }
    end
  end
end
