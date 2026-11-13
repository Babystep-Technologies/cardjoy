# typed: false

# A user's own mailing address. Mirrors Contact's address handling (same "set
# any field, the required ones are now required" validation), kept as its own
# concern because the rest of User is about credits and auth, not addresses.
#
# Typed `false` like the other model concerns: the validation and callbacks
# call back into ActiveRecord methods that only exist on the including class.
module HasReturnAddress
  extend ActiveSupport::Concern

  COUNTRY_CODE_FORMAT = /\A[A-Z]{2}\z/

  ADDRESS_FIELDS = %i[
    return_address_line1 return_address_line2 return_address_city
    return_address_region return_address_postal_code return_address_country_code
  ].freeze

  # The subset needed to deliver to an address. `region` is out deliberately,
  # same reasoning as Contact: plenty of countries have no
  # state/province.
  REQUIRED_ADDRESS_FIELDS = %i[
    return_address_line1 return_address_city return_address_postal_code return_address_country_code
  ].freeze

  INCOMPLETE_ADDRESS_MESSAGE = "is required to complete the return address"

  included do
    before_validation :normalize_return_address

    validates :return_address_country_code,
              format: { with: COUNTRY_CODE_FORMAT, message: "is not a valid country code" },
              allow_blank: true
    # A half-filled address is worse than none: it would read as complete
    # while missing a line a carrier needs.
    validates(*REQUIRED_ADDRESS_FIELDS,
              presence: { message: INCOMPLETE_ADDRESS_MESSAGE },
              if: :any_return_address_field?)
  end

  # Whether there's enough of a return address for a carrier to deliver to it.
  def return_address_complete?
    REQUIRED_ADDRESS_FIELDS.all? { |field| public_send(field).present? }
  end

  private

  # True once the user has typed anything at all into the address, including
  # the optional parts — that's what turns the partial-address validation on.
  def any_return_address_field?
    ADDRESS_FIELDS.any? { |field| public_send(field).present? }
  end

  # Same spirit as Contact#normalize_address: take what a human typed and
  # store something canonical. A field left blank becomes nil so "cleared" is
  # one value rather than two, and the country code is upper-cased so "us" and
  # "US" are the same country.
  def normalize_return_address
    ADDRESS_FIELDS.each do |field|
      current = public_send(field)
      next if current.nil?

      stripped = current.strip
      public_send(:"#{field}=", stripped.presence)
    end

    self.return_address_country_code = return_address_country_code&.upcase
  end
end
