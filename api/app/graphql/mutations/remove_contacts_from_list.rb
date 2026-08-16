# typed: true

module Mutations
  # Take contacts off a list. The mirror of AddContactsToList: bulk, and
  # idempotent — an id that isn't on the list is a no-op, not an error.
  #
  # Unlike the add side there is no ownership check on `contact_ids`. It would
  # be redundant: the delete is scoped to the caller's own list, and a contact
  # belonging to someone else can't be on it in the first place, so the worst an
  # arbitrary id can do here is match nothing.
  class RemoveContactsFromList < BaseMutation
    argument :list_id, ID, required: true
    argument :contact_ids, [ ID ], required: true

    field :contact_list, Types::ContactListType, null: true
    field :errors, [ String ], null: false

    def resolve(list_id:, contact_ids:)
      user = context[:current_user]
      return { contact_list: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      contact_list = user.contact_lists.find_by(id: list_id)
      return { contact_list: nil, errors: [ ::ContactList::NOT_FOUND_ERROR ] } unless contact_list

      contact_list.contact_list_memberships.where(contact_id: contact_ids).destroy_all

      { contact_list: contact_list.reload, errors: [] }
    end
  end
end
