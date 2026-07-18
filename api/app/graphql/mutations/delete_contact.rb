# typed: true

module Mutations
  class DeleteContact < BaseMutation
    argument :contact_id, ID, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(contact_id:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      contact = user.contacts.find_by(id: contact_id)
      return { success: false, errors: [ "Contact not found or not owned by user" ] } unless contact

      contact.destroy!
      { success: true, errors: [] }
    end
  end
end
