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

    # The owner, and the moderation state admin acts on (#178). Named to match
    # Types::CardType so the dashboard renders either product through one
    # component. There is no `locked`: a holiday card takes no contributions, so
    # there is nothing to lock.
    #
    # `user` is always the caller for every non-admin query that returns this
    # type, so it exposes nothing new there — it is here because the admin list
    # is the first reader that does not already know whose card this is.
    field :user, Types::UserType, null: false
    field :flagged, Boolean, null: false
    field :deleted, Boolean, null: false

    # The proof state, as three things the editor can render directly rather
    # than as a digest it would have to compare itself. `proofCurrent` is
    # deliberately not "has a proof": a card whose design moved after its render
    # still has a `proofUrl`, and the editor shows it while telling the user it
    # is out of date.
    field :proof_url, String, null: true
    field :proof_generated_at, GraphQL::Types::ISO8601DateTime, null: true
    field :proof_current, Boolean, null: false
    field :proof_approved, Boolean, null: false

    # What became of this card in the post, as counts (#153). Batch-loaded, so
    # the dashboard's list of cards costs one grouped query rather than one per
    # card — see Sources::HolidayCardOrderSummaryByCardId.
    field :order_summary, Types::HolidayCardOrderSummaryType, null: false,
      description: "How many pieces this card has been mailed as, and how they went."

    def order_summary
      dataloader.with(Sources::HolidayCardOrderSummaryByCardId).load(object.id)
    end

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
