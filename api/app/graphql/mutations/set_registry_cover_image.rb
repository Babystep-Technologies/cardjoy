# typed: true
# frozen_string_literal: true

module Mutations
  # Owner-only. Attaches (or replaces) a registry's cover image from a multipart upload (#247).
  # A separate mutation rather than an `upsertWishList` argument, so saving the form never has to
  # be a file upload.
  class SetRegistryCoverImage < BaseMutation
    argument :registry_external_id, String, required: true
    argument :cover_image_file, ApolloUploadServer::Upload, required: true

    field :wish_list, Types::WishListType, null: true
    field :errors, [ String ], null: false

    def resolve(registry_external_id:, cover_image_file:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      list = user.wish_lists.find_by(external_id: registry_external_id)
      return failure("Registry not found") unless list

      # Check the upload before attaching it, so a bad file can never displace the current image.
      blob = ActiveStorage::Blob.create_and_upload!(
        io: cover_image_file.to_io, filename: cover_image_file.original_filename, identify: true
      )
      problem = image_problem(blob)
      if problem
        blob.purge
        return failure(problem)
      end

      list.cover_image.attach(blob)
      { wish_list: list.reload, errors: [] }
    end

    private

    def image_problem(blob)
      return "Cover image must be a PNG, JPEG, GIF or WebP image" unless WishList::COVER_IMAGE_TYPES.include?(blob.content_type)
      return "Cover image must be less than 10MB" if blob.byte_size >= WishList::COVER_IMAGE_MAX_SIZE

      nil
    end

    def failure(*messages)
      { wish_list: nil, errors: messages }
    end
  end
end
