# typed: true
# frozen_string_literal: true

module Queries
  # The signed-in user's contact lists, alphabetically.
  class MyContactLists < BaseQuery
    type [ Types::ContactListType ], null: false

    def resolve
      user = context[:current_user]
      raise GraphQL::ExecutionError, NOT_AUTHENTICATED_ERROR unless user

      user.contact_lists.order(:name)
    end
  end
end
