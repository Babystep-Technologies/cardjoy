# typed: true
# frozen_string_literal: true

module Types
  class HolidayCardType < Types::BaseObject
    field :id, ID, null: false
    field :external_id, String, null: false
    # The user's own name for the card ("Shen family 2026"). Never printed.
    field :title, String, null: true
    field :size, String, null: false
    field :template_id, String, null: false
    # The whole design document. Its shape is owned by HolidayCard's validator
    # and the static template catalogue, so it crosses the wire as JSON rather
    # than as a field-by-field type.
    field :design_config, GraphQL::Types::JSON, null: false
    field :photos, [ Types::HolidayCardPhotoType ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def photos
      object.photos.blobs.map { |blob| { blob:, card: object } }
    end
  end
end
