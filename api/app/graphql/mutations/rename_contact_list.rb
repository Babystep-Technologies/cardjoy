# typed: true

module Mutations
  class RenameContactList < BaseMutation
    argument :id, ID, required: true
    argument :name, String, required: true

    field :contact_list, Types::ContactListType, null: true
    field :errors, [ String ], null: false

    def resolve(id:, name:)
      user = context[:current_user]
      return { contact_list: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      contact_list = user.contact_lists.find_by(id: id)
      return { contact_list: nil, errors: [ ::ContactList::NOT_FOUND_ERROR ] } unless contact_list

      contact_list.name = name
      if contact_list.save
        { contact_list:, errors: [] }
      else
        { contact_list: nil, errors: contact_list.errors.full_messages }
      end
    end
  end
end
