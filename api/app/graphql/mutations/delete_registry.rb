# typed: true

module Mutations
  # Deletes one of the caller's registries along with its items, cash destinations and any
  # reservations guests made against it (#245).
  class DeleteRegistry < BaseMutation
    argument :external_id, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(external_id:)
      user = context[:current_user]
      return { success: false, errors: [ "You must be signed in" ] } unless user

      list = user.wish_lists.find_by(external_id: external_id)
      return { success: false, errors: [ "Registry not found" ] } unless list

      list.destroy!
      { success: true, errors: [] }
    end
  end
end
