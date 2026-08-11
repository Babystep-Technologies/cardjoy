# typed: true

module Mutations
  class DeleteCard < BaseMutation
    argument :card_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(card_id:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      # An ordinary member of the owning organization may see this card but not
      # delete it; the owner and an org admin may. See
      # OrganizationScoped#editable_by?.
      card = Card.find_by(external_id: card_id)
      return { success: false, errors: [ "Card not found or not owned by user" ] } unless card&.editable_by?(user)

      card.delete!
      { success: true, errors: [] }
    end
  end
end
