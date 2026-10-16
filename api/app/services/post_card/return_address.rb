# typed: true
# frozen_string_literal: true

# CardJoy's own mailing address — the `from` on every postcard we hand to
# PostGrid, proof or live order (issue #233).
#
# Before this existed, both the proof and the live order reused a
# USPS-reserved placeholder address (`ProofGenerator::PLACEHOLDER_ADDRESS`),
# which meant every physical card actually mailed printed that placeholder as
# its return address rather than anything belonging to CardJoy.
#
# Per CLAUDE.md, config reads from the environment with a Rails credentials
# fallback. This repo is public, so the real address lives in neither this
# file nor source control — only env/credentials carry it, the same way the
# PostGrid keys themselves do (see `PostGrid`).
module PostCard::ReturnAddress
  extend T::Sig

  REQUIRED_FIELDS = %i[address_line1 city region postal_code country].freeze

  class << self
    extend T::Sig

    sig { returns(T::Hash[Symbol, T.nilable(String)]) }
    def address
      {
        addressLine1: field(:address_line1),
        addressLine2: field(:address_line2),
        city: field(:city),
        provinceOrState: field(:region),
        postalOrZip: field(:postal_code),
        countryCode: field(:country)
      }
    end

    # False when any required field is missing. `addressLine2` is the only
    # optional one. Callers raise rather than hand PostGrid a return address
    # with a blank line.
    sig { returns(T::Boolean) }
    def configured?
      REQUIRED_FIELDS.all? { |name| env_or_credential(name).present? }
    end

    private

    def field(name)
      env_or_credential(name).presence
    end

    ENV_KEYS = {
      address_line1: "CARDJOY_RETURN_ADDRESS_LINE1",
      address_line2: "CARDJOY_RETURN_ADDRESS_LINE2",
      city: "CARDJOY_RETURN_ADDRESS_CITY",
      region: "CARDJOY_RETURN_ADDRESS_REGION",
      postal_code: "CARDJOY_RETURN_ADDRESS_POSTAL_CODE",
      country: "CARDJOY_RETURN_ADDRESS_COUNTRY"
    }.freeze

    # ENV first, encrypted credentials second — the same convention
    # `PostGrid.env_or_credential` follows.
    def env_or_credential(name)
      ENV[ENV_KEYS.fetch(name)].presence ||
        Rails.application.credentials.dig(:cardjoy, :return_address, name).presence
    end
  end
end
