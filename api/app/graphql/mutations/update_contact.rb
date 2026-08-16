# typed: true

module Mutations
  class UpdateContact < BaseMutation
    argument :contact_id, ID, required: true
    argument :name, String, required: false
    argument :email, String, required: false
    argument :relationship, String, required: false
    argument :phone, String, required: false
    argument :notes, String, required: false

    # The optional mailing address; see the note on CreateContact for why these are
    # six loose arguments and not a nested AddressInput.
    argument :address_line1, String, required: false
    argument :address_line2, String, required: false
    argument :city, String, required: false
    argument :region, String, required: false
    argument :postal_code, String, required: false
    argument :country_code, String, required: false

    field :contact, Types::ContactType, null: true
    field :errors, [ String ], null: false

    def resolve(contact_id:, name: nil, email: nil, relationship: nil, phone: nil, notes: nil, **address)
      user = context[:current_user]
      return { contact: nil, errors: [ "Not authenticated" ] } unless user

      contact = user.contacts.find_by(id: contact_id)
      return { contact: nil, errors: [ "Contact not found or not owned by user" ] } unless contact

      contact.name = name if name.present?
      # email/relationship/phone/notes are nullable, so an explicit "" clears them.
      contact.email = email unless email.nil?
      contact.relationship = relationship unless relationship.nil?
      contact.phone = phone unless phone.nil?
      contact.notes = notes unless notes.nil?
      # Same rule for the address: an omitted field keeps its stored value, an
      # explicit "" clears it (Contact#normalize_address turns that back into nil).
      Contact::ADDRESS_FIELDS.each do |field|
        value = address[field]
        contact.public_send(:"#{field}=", value) unless value.nil?
      end

      if contact.save
        { contact:, errors: [] }
      else
        { contact: nil, errors: contact.errors.full_messages }
      end
    end
  end
end
