# typed: true

module Mutations
  # Put contacts on a list. Bulk by design: building "the 2026 card list" is one
  # gesture over forty people, and a per-contact mutation would make it forty
  # round trips.
  #
  # Idempotent — a contact already on the list is a no-op, not an error, so the
  # client never has to diff before it writes.
  class AddContactsToList < BaseMutation
    argument :list_id, ID, required: true
    argument :contact_ids, [ ID ], required: true

    field :contact_list, Types::ContactListType, null: true
    field :errors, [ String ], null: false

    def resolve(list_id:, contact_ids:)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      contact_list = user.contact_lists.find_by(id: list_id)
      return failure(::ContactList::NOT_FOUND_ERROR) unless contact_list

      requested_ids = contact_ids.map(&:to_s).uniq
      owned_ids = user.contacts.where(id: requested_ids).pluck(:id)

      # All-or-nothing: a batch that mixes the caller's contacts with someone
      # else's adds nothing at all. Partially applying it would leak which ids
      # exist, and would leave the client's list quietly out of sync with what
      # it asked for.
      return failure(NOT_AUTHORIZED_ERROR) unless owned_ids.length == requested_ids.length

      new_ids = owned_ids - contact_list.contact_ids
      ::ContactList.transaction do
        new_ids.each { |contact_id| contact_list.contact_list_memberships.create!(contact_id:) }
      end

      { contact_list: contact_list.reload, errors: [] }
    end

    private

    def failure(message)
      { contact_list: nil, errors: [ message ] }
    end
  end
end
