# typed: true

module Mutations
  class DeleteOccasion < BaseMutation
    argument :occasion_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(occasion_id:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      occasion = user.occasions.find_by(id: occasion_id)
      return { success: false, errors: [ "Occasion not found or not owned by user" ] } unless occasion

      occasion.destroy!
      { success: true, errors: [] }
    end
  end
end
