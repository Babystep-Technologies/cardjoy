# typed: true

module Mutations
  # Set or change the current user's own return address — the `from` on every
  # physical postcard they send (issue #233). Always the caller's own; there
  # is no id argument because there is nothing to disambiguate.
  class UpdateReturnAddress < BaseMutation
    FIELD_MAP = {
      address_line1: :return_address_line1,
      address_line2: :return_address_line2,
      city: :return_address_city,
      region: :return_address_region,
      postal_code: :return_address_postal_code,
      country_code: :return_address_country_code
    }.freeze

    argument :address_line1, String, required: false
    argument :address_line2, String, required: false
    argument :city, String, required: false
    argument :region, String, required: false
    argument :postal_code, String, required: false
    argument :country_code, String, required: false

    field :user, Types::UserType, null: true
    field :errors, [ String ], null: false

    # An omitted argument keeps its stored value; an explicit "" clears it
    # (HasReturnAddress#normalize_return_address turns that back into nil) —
    # the same contract Mutations::UpdateContact uses for a contact's address.
    def resolve(**address)
      user = context[:current_user]
      return { user: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      FIELD_MAP.each do |arg, column|
        value = address[arg]
        user.public_send(:"#{column}=", value) unless value.nil?
      end

      if user.save
        { user:, errors: [] }
      else
        { user: nil, errors: user.errors.full_messages }
      end
    end
  end
end
