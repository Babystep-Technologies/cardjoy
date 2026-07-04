# typed: true

module Mutations
  class DeleteCard < BaseMutation
    argument :card_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(card_id:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      card = Card.find_by(external_id: card_id, user: user)
      return { success: false, errors: [ "Card not found or not owned by user" ] } unless card

      card.delete!
      { success: true, errors: [] }
    end
  end
end
