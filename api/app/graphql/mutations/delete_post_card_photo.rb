# typed: true
# frozen_string_literal: true

module Mutations
  # Removes one photo from a post card.
  #
  # Purging the attachment is only half the job. `design_config` may point a slot
  # at this blob, and PostCard's validator rejects a document referencing a
  # photo that is not attached — so a purge on its own would leave a card that
  # cannot be saved again, with no way for the editor to repair it. Both halves
  # happen in one transaction. Compare `remove_card_cover_image.rb`, which has
  # nothing to scrub because a cover image is not referenced from a document.
  class DeletePostCardPhoto < BaseMutation
    argument :external_id, String, required: true
    argument :blob_id, ID, required: true

    field :post_card, Types::PostCardType, null: true
    field :errors, [ String ], null: false

    def resolve(external_id:, blob_id:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      post_card = PostCard.find_by(external_id:)
      return failure("Post card not found") unless post_card
      return failure(NOT_AUTHORIZED_ERROR) unless post_card.user_id == user.id

      attachment = post_card.photos.attachments.find { |a| a.blob_id.to_s == blob_id.to_s }
      return failure("Photo not found on this card") unless attachment

      # Scrub before purging: `purge` destroys the file in storage, which no
      # transaction can roll back, so a document that somehow fails to save
      # should abort while the photo is still there.
      ApplicationRecord.transaction do
        post_card.design_config = scrub(post_card.design_config, blob_id)
        post_card.save!
        attachment.purge
      end

      { post_card: post_card.reload, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      # Only reachable if the stored document was already invalid for some
      # reason unrelated to this blob. Surface it rather than 500-ing, and leave
      # the photo in place so nothing is destroyed on the way out.
      { post_card: nil, errors: e.record.errors.full_messages }
    end

    private

    # Drops every photo placement pointing at `blob_id`, in every panel.
    #
    # Compared as strings on purpose: `blobId` crosses the wire as a GraphQL `ID`
    # (a string) while a stored document may hold the same id as a JSON number,
    # and a mismatch here would silently leave the dangling reference this whole
    # mutation exists to prevent.
    def scrub(design_config, blob_id)
      return design_config unless design_config.is_a?(Hash)

      design_config.each_with_object({}) do |(key, value), scrubbed|
        scrubbed[key] = PostCard::PANELS.include?(key.to_s) ? scrub_panel(value, blob_id) : value
      end
    end

    def scrub_panel(panel, blob_id)
      return panel unless panel.is_a?(Hash)

      photos = panel["photos"] || panel[:photos]
      return panel unless photos.is_a?(Hash)

      kept = photos.reject { |_slot_id, photo| photo.is_a?(Hash) && (photo["blob_id"] || photo[:blob_id]).to_s == blob_id.to_s }

      panel.merge("photos" => kept)
    end

    def failure(errors)
      { post_card: nil, errors: Array(errors) }
    end
  end
end
