# typed: true

module Types
  # A user's own mailing address — the `from` on every physical postcard they
  # send (issue #233). Field names mirror the Contact/AddressSuggestion
  # address fields (`addressLine1`, `city`, …) rather than the `return*`
  # prefix the underlying User columns carry, so the frontend's address
  # helpers work against this the same way they do against a contact's.
  class ReturnAddressType < Types::BaseObject
    field :address_line1, String, null: true, method: :return_address_line1
    field :address_line2, String, null: true, method: :return_address_line2
    field :city, String, null: true, method: :return_address_city
    field :region, String, null: true, method: :return_address_region
    field :postal_code, String, null: true, method: :return_address_postal_code
    field :country_code, String, null: true, method: :return_address_country_code

    # Whether this is enough of an address for PostGrid to accept it — the
    # same check `Mutations::SendPostCard` gates sending on.
    field :complete, Boolean, null: false, method: :return_address_complete?
  end
end
