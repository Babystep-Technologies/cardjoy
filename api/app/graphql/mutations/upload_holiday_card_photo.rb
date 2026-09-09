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
        errors = friendly_errors(holiday_card.errors.full_messages, photo_file)
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
    def friendly_errors(messages, photo_file)
      messages.map do |message|
        if message.include?("less than 10")
          "Photo is too large. Please choose an image smaller than 10MB."
        elsif message.include?("valid image format")
          wrong_format_message(photo_file)
        else
          message
        end
      end
    end

    # The content type validation reads the file's actual bytes, not its name —
    # that is the point of it, since an extension can say anything. But it means
    # the person who picked a file their computer calls a JPG gets told to pick a
    # PNG, JPG, or GIF, which reads as nonsense and leaves them nothing to do.
    #
    # So name what the file actually is. HEIC gets its own sentence because it is
    # by far the common case: it is what an iPhone shoots by default, and macOS
    # will happily report `image/jpeg` for one, so it passes every check that
    # trusts the extension and fails this one.
    def wrong_format_message(photo_file)
      detected = detected_content_type(photo_file)

      case detected
      when "image/heic", "image/heif"
        "That photo is in Apple's HEIC format, which we cannot print. On your iPhone, " \
          "either set Settings › Camera › Formats to \"Most Compatible\", or export this " \
          "photo as a JPG and upload that."
      when nil, *HolidayCard::PRINTABLE_IMAGE_TYPES
        # Either the bytes were unreadable, or Marcel disagrees with the
        # validator's own sniff. Naming a type the validator just rejected would
        # be worse than saying nothing, so fall back to the plain rule.
        "Photo must be a PNG, JPG, or GIF image."
      else
        "That file is #{format_name(detected)}, not a PNG, JPG, or GIF. Please convert it and try again."
      end
    end

    FORMAT_NAMES = {
      "image/webp" => "a WebP image",
      "image/bmp" => "a BMP image",
      "image/tiff" => "a TIFF image",
      "image/avif" => "an AVIF image",
      "image/svg+xml" => "an SVG",
      "application/pdf" => "a PDF"
    }.freeze

    def format_name(content_type)
      FORMAT_NAMES.fetch(content_type) { "a #{content_type} file" }
    end

    # Marcel reads the leading bytes, the same way the validator's spoof check
    # does, so this reports the type the validator actually objected to rather
    # than a second opinion. Best effort: a message is not worth raising over, so
    # anything unreadable falls back to the generic wording above.
    def detected_content_type(photo_file)
      @detected_content_type ||= begin
        io = photo_file.to_io
        io.rewind
        Marcel::MimeType.for(io, name: photo_file.original_filename)
      rescue StandardError => e
        Rails.logger.warn("Could not sniff rejected upload's content type: #{e.class}: #{e.message}")
        nil
      end
    end

    def failure(errors)
      { photo: nil, errors: Array(errors) }
    end
  end
end
