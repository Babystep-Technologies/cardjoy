# typed: true

module Mutations
  class RemoveCardCoverImage < BaseMutation
    argument :card_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(card_id:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id)
      return { success: false, errors: [ "Card not found or not owned by user" ] } unless card&.editable_by?(user)

      if card.cover_image.attached?
        card.cover_image.purge
        { success: true, errors: [] }
      else
        { success: false, errors: [ "No cover image to remove" ] }
      end
    end
  end
end
