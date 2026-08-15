# typed: true
# frozen_string_literal: true

module Types
  # One photo uploaded to a holiday card. `blobId` is the id `design_config`
  # uses to point a photo slot at this file, so the editor needs it alongside
  # the URL.
  class HolidayCardPhotoType < Types::BaseObject
    field :blob_id, ID, null: false
    field :filename, String, null: false
    field :content_type, String, null: true
    field :byte_size, Integer, null: false
    field :url, String, null: true

    def blob_id
      object[:blob].id
    end

    def filename
      object[:blob].filename.to_s
    end

    def content_type
      object[:blob].content_type
    end

    def byte_size
      object[:blob].byte_size
    end

    def url
      object[:card].photo_url(object[:blob])
    end
  end
end
