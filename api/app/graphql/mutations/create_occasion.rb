# typed: true

module Mutations
  class CreateOccasion < BaseMutation
    argument :contact_id, ID, required: true
    argument :kind, String, required: true
    argument :occurs_on, GraphQL::Types::ISO8601Date, required: true
    argument :recurring, Boolean, required: false

    field :occasion, Types::OccasionType, null: true
    field :errors, [ String ], null: false

    def resolve(contact_id:, kind:, occurs_on:, recurring: nil)
      user = context[:current_user]
      return { occasion: nil, errors: [ "Not authenticated" ] } unless user

      contact = user.contacts.find_by(id: contact_id)
      return { occasion: nil, errors: [ "Contact not found or not owned by user" ] } unless contact

      occasion = contact.occasions.build(kind:, occurs_on:)
      occasion.recurring = recurring unless recurring.nil?

      if occasion.save
        { occasion:, errors: [] }
      else
        { occasion: nil, errors: occasion.errors.full_messages }
      end
    end
  end
end
