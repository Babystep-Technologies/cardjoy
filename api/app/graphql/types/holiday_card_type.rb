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

    # The proof state, as three things the editor can render directly rather
    # than as a digest it would have to compare itself. `proofCurrent` is
    # deliberately not "has a proof": a card whose design moved after its render
    # still has a `proofUrl`, and the editor shows it while telling the user it
    # is out of date.
    field :proof_url, String, null: true
    field :proof_generated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :proof_current, Boolean, null: false
    field :proof_approved, Boolean, null: false

    def proof_current
      object.proof_current?
    end

    def proof_approved
      object.proof_approved?
    end

    def photos
      object.photos.blobs.map { |blob| { blob:, card: object } }
    end
  end
end
