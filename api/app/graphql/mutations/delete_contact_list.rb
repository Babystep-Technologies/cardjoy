# typed: true

module Mutations
  class DeleteContactList < BaseMutation
    argument :id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(id:)
      user = context[:current_user]
      return { success: false, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      contact_list = user.contact_lists.find_by(id: id)
      return { success: false, errors: [ ::ContactList::NOT_FOUND_ERROR ] } unless contact_list

      # Takes the memberships with it (ContactList `dependent: :destroy`) and
      # leaves the contacts themselves alone.
      contact_list.destroy!
      { success: true, errors: [] }
    end
  end
end
