# typed: true
# frozen_string_literal: true

module Mutations
  class ToggleLockCard < BaseMutation
    argument :card_id, ID, required: true

    field :success, Boolean, null: false
    field :locked, Boolean, null: true
    field :errors, [ String ], null: false

    def resolve(card_id:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id)
      return { success: false, errors: [ "Card not found" ] } unless card
      return { success: false, errors: [ "Unauthorized" ] } unless card.editable_by?(user)

      begin
        card.locked ? card.unlock! : card.lock!
        { success: true, locked: card.locked, errors: [] }
      rescue => e
        { success: false, errors: [ e.message ] }
      end
    end
  end
end
