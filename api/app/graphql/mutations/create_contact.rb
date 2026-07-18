# typed: true

module Mutations
  class CreateContact < BaseMutation
    argument :name, String, required: true
    argument :email, String, required: false
    argument :relationship, String, required: false

    field :contact, Types::ContactType, null: true
    field :errors, [ String ], null: false

    def resolve(name:, email: nil, relationship: nil)
      user = context[:current_user]
      return { contact: nil, errors: [ "Not authenticated" ] } unless user

      contact = user.contacts.build(name:, email:, relationship:)
      if contact.save
        { contact:, errors: [] }
      else
        { contact: nil, errors: contact.errors.full_messages }
      end
    end
  end
end
