# typed: true

module Types
  class ContactType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: true
    field :relationship, String, null: true
    field :phone, String, null: true
    field :notes, String, null: true

    # Optional mailing address. All null unless the user has filled one in; either
    # all four of line1/city/postalCode/countryCode are set or none are, which is
    # what `mailable` reports.
    field :address_line1, String, null: true
    field :address_line2, String, null: true
    field :city, String, null: true
    field :region, String, null: true
    field :postal_code, String, null: true
    field :country_code, String, null: true
    field :mailable, Boolean, null: false, method: :mailable?

    field :occasions, [ Types::OccasionType ], null: false
    # The lists this contact is on, so the contacts page can show membership
    # inline instead of cross-referencing myContactLists client-side.
    field :contact_lists, [ Types::ContactListType ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def contact_lists
      object.contact_lists.order(:name)
    end
  end
end
