# typed: true

module Mutations
  class CreateContactList < BaseMutation
    argument :name, String, required: true

    field :contact_list, Types::ContactListType, null: true
    field :errors, [ String ], null: false

    def resolve(name:)
      user = context[:current_user]
      return { contact_list: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      contact_list = user.contact_lists.build(name:)
      if contact_list.save
        { contact_list:, errors: [] }
      else
        { contact_list: nil, errors: contact_list.errors.full_messages }
      end
    end
  end
end
