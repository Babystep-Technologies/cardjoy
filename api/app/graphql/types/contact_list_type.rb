# typed: true

module Types
  class ContactListType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false

    # Both counts so a list row can render "38 of 42 contacts have an address"
    # without asking for `contacts` at all.
    field :contacts_count, Integer, null: false
    field :mailable_contacts_count, Integer, null: false

    field :contacts, [ Types::ContactType ], null: false

    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Alphabetical, matching Queries::MyContacts — a list is something the user
    # scans by name.
    def contacts
      object.contacts.order(:name)
    end
  end
end
