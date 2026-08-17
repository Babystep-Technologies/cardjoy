# typed: true
# frozen_string_literal: true

module Queries
  # One of the caller's own contact lists, with its contacts.
  #
  # Someone else's list returns nil rather than an error, which is the same
  # answer as an id that does not exist: a caller can't use this to learn which
  # lists exist.
  class ContactList < BaseQuery
    type Types::ContactListType, null: true
    argument :id, ID, required: true

    def resolve(id:)
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.contact_lists.find_by(id: id)
    end
  end
end
