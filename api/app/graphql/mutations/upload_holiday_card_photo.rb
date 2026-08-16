# typed: true
# frozen_string_literal: true

module Mutations
  # Attaches one family photo to a holiday card and hands back the blob id the
  # editor needs to place it in a slot.
  #
  # Direct upload only. Unlike `create_card.rb` there is no `photoUrl` sibling
  # that fetches a URL server-side: holiday card photos are the user's own
  # pictures off their phone, not artwork picked from a gallery, so there is
  # nothing to download and no reason to give the server an arbitrary URL to
  # fetch.
  class UploadHolidayCardPhoto < BaseMutation
    argument :external_id, String, required: true
    argument :photo_file, ApolloUploadServer::Upload, required: true

    field :photo, Types::HolidayCardPhotoType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:, photo_file:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      holiday_card = HolidayCard.find_by(external_id:)
      return failure("Holiday card not found") unless holiday_card
      return failure(NOT_AUTHORIZED_ERROR) unless holiday_card.user_id == user.id

      if holiday_card.attached_photo_blob_ids.size >= HolidayCard::MAX_PHOTOS
        return failure("A holiday card can hold at most #{HolidayCard::MAX_PHOTOS} photos. Remove one before uploading another.")
      end

      return failure("Photo file is missing") unless photo_file.respond_to?(:to_io)

      # `attach` on a persisted record saves immediately, so a photo that fails
      # the model's content-type or size validation leaves neither an attachment
      # nor a blob row behind — it only populates `errors`.
      holiday_card.photos.attach(io: photo_file.to_io, filename: photo_file.original_filename)

      if holiday_card.errors.any?
        errors = friendly_errors(holiday_card.errors.full_messages)
        # Drop the rejected in-memory attachment so the record isn't left dirty.
        holiday_card.reload
        return failure(errors)
      end

      { photo: { blob: holiday_card.photos.blobs.last, card: holiday_card }, errors: [] }
    end

    private

    # Mirrors the message rewriting in `create_card.rb`: the raw validator text
    # ("Photos must be less than 10MB") reads like a schema note rather than
    # something a person can act on.
    def friendly_errors(messages)
      messages.map do |message|
        if message.include?("less than 10")
          "Photo is too large. Please choose an image smaller than 10MB."
        elsif message.include?("valid image format")
          "Photo must be a PNG, JPG, or GIF image."
        else
          message
        end
      end
    end

    def failure(errors)
      { photo: nil, errors: Array(errors) }
    end
  end
end
