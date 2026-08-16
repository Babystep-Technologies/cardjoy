# typed: true

module Mutations
  class CreateContact < BaseMutation
    argument :name, String, required: true
    argument :email, String, required: false
    argument :relationship, String, required: false
    argument :phone, String, required: false
    argument :notes, String, required: false

    # The optional mailing address. Six loose arguments rather than an AddressInput
    # object so that updateContact can keep its per-field "omitted means unchanged"
    # semantics — a nested input can't distinguish an omitted field from a cleared
    # one without a second layer of nil-juggling. See Contact::ADDRESS_FIELDS.
    argument :address_line1, String, required: false
    argument :address_line2, String, required: false
    argument :city, String, required: false
    argument :region, String, required: false
    argument :postal_code, String, required: false
    argument :country_code, String, required: false

    field :contact, Types::ContactType, null: true
    field :errors, [ String ], null: false

    # `**address` collects the six address arguments above; GraphQL only ever passes
    # arguments this mutation declares, so nothing unexpected reaches the model.
    def resolve(name:, email: nil, relationship: nil, phone: nil, notes: nil, **address)
      user = context[:current_user]
      return { contact: nil, errors: [ "Not authenticated" ] } unless user

      contact = user.contacts.build(name:, email:, relationship:, phone:, notes:, **address)
      if contact.save
        { contact:, errors: [] }
      else
        { contact: nil, errors: contact.errors.full_messages }
      end
    end
  end
end
