# typed: true

module Mutations
  class CreateCoverStyle < BaseMutation
    argument :file, ApolloUploadServer::Upload, required: true
    argument :tag_names, [ String ], required: true

    field :style, Types::StyleType, null: true
    field :errors, [ String ], null: false

    def resolve(file:, tag_names:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, "Admin access required" unless admin

      # copy the file to a temporary location
      # to avoid the file being deleted before we can use it
      buffered_file = Tempfile.new([ "upload", File.extname(file.original_filename) ])
      buffered_file.binmode
      buffered_file.write(file.read)
      buffered_file.rewind

      style = Style.new(
        kind: "cover",
        source: nil, # we now rely on the image attachment
        name: file.original_filename
      )
      style.image.attach(io: buffered_file, filename: file.original_filename)

      tag_names.each do |tag_name|
        tag = Tag.find_or_create_by!(name: tag_name.strip.downcase)
        style.tags << tag unless style.tags.include?(tag)
      end

      if style.save
        { style: style, errors: [] }
      else
        { style: nil, errors: style.errors.full_messages }
      end
    rescue => e
      { style: nil, errors: [ e.message ] }
    end
  end
end
