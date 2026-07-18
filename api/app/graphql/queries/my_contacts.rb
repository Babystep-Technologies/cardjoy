# typed: true

module Queries
  class MyContacts < BaseQuery
    type [ Types::ContactType ], null: false

    def resolve
      user = context[:current_user]
      return [] unless user

      user.contacts.order(:name)
    end
  end
end
