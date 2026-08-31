# typed: true
# frozen_string_literal: true

module PostGrid
  # Wraps PostGrid's address verification API.
  #
  # ## Why this matters more than it sounds
  #
  # PostGrid has no price-quote endpoint. A postcard's cost is a rate-card
  # lookup on size × mailing class × **destination zone**, and verification is
  # how we learn the zone — so pricing depends on this file, not just delivery.
  #
  # It is also how we stop someone paying for a card that comes back marked
  # "return to sender" because the apartment number was missing.
  #
  # ## What it does not do
  #
  # It does not write to the contact, and it does not apply PostGrid's
  # canonicalized form. Both are the caller's call. People know their own
  # address better than a database does, and silently rewriting "Apt 4B" is
  # exactly how a card ends up in the wrong mailbox.
  class AddressVerification
    extend T::Sig

    VERIFY_PATH = "/verifications"

    # PostGrid's own verdicts. `corrected` means deliverable *after* it fixed
    # something — still deliverable, so it maps to verified on our side, with
    # the correction handed back as a suggestion for the user to accept.
    DELIVERABLE_STATUSES = %w[verified corrected].freeze

    # Pricing zones, MVP resolution. Deliberately coarse: PostGrid's US rate
    # card doesn't vary by state for the classes we mail, so a finer split
    # would be three values pretending to be data.
    ZONE_US_DOMESTIC = "us_domestic"
    ZONE_CANADA = "canada"
    ZONE_INTERNATIONAL = "international"

    # The value object the pricing service and the mutation both consume.
    #
    # `zone` is present even for an undeliverable address — an unverifiable US
    # address is still a US-zone attempt, and quoting it costs nothing. It's
    # `deliverable?` that gates spending money.
    Result = Struct.new(
      :deliverable,
      :status,
      :line1,
      :line2,
      :city,
      :region,
      :postal_code,
      :country_code,
      :zone,
      :errors,
      keyword_init: true
    ) do
      def deliverable?
        deliverable
      end

      # The canonicalized address, in *our* column names, so a caller can hand
      # it to a Contact without a second translation step. Nil-valued keys are
      # dropped: PostGrid returning "" for line2 means "no line2", not "clear
      # the line2 the user typed".
      def canonical_address
        {
          address_line1: line1,
          address_line2: line2,
          city: city,
          region: region,
          postal_code: postal_code,
          country_code: country_code
        }.compact_blank
      end

      # True when PostGrid's canonical form differs from what the user typed,
      # i.e. when there is actually something worth offering them.
      def differs_from?(contact)
        canonical_address.any? { |field, value| contact.public_send(field).to_s.casecmp(value.to_s) != 0 }
      end
    end

    sig { params(mode: Symbol, client: T.nilable(Client)).void }
    def initialize(mode: PostGrid.default_mode, client: nil)
      @client = client || Client.new(mode:, base_url: Client::ADDRESS_VERIFICATION_BASE_URL)
    end

    # Verify a Contact's mailing address. Raises PostGrid::Error subclasses —
    # the caller decides what a failure means to the user.
    sig { params(contact: Contact).returns(Result) }
    def verify_contact(contact)
      verify(
        line1: contact.address_line1,
        line2: contact.address_line2,
        city: contact.city,
        region: contact.region,
        postal_code: contact.postal_code,
        country_code: contact.country_code
      )
    end

    sig do
      params(
        line1: T.nilable(String),
        line2: T.nilable(String),
        city: T.nilable(String),
        region: T.nilable(String),
        postal_code: T.nilable(String),
        country_code: T.nilable(String)
      ).returns(Result)
    end
    def verify(line1:, line2: nil, city: nil, region: nil, postal_code: nil, country_code: nil)
      payload = @client.post(VERIFY_PATH, body: { address: {
        line1: line1,
        line2: line2,
        city: city,
        provinceOrState: region,
        postalOrZip: postal_code,
        country: country_code
      }.compact })

      build_result(payload.fetch("data", {}), fallback_country: country_code)
    end

    private

    def build_result(data, fallback_country:)
      status = data["status"].to_s
      # PostGrid echoes the country it resolved; when it couldn't resolve
      # anything, fall back to what the user told us so an undeliverable
      # address still lands in the right pricing zone.
      country = data["country"].presence || fallback_country

      Result.new(
        deliverable: DELIVERABLE_STATUSES.include?(status),
        status: status.presence,
        line1: data["line1"].presence,
        line2: data["line2"].presence,
        city: data["city"].presence,
        region: data["provinceOrState"].presence,
        postal_code: postal_code_from(data),
        country_code: country&.upcase,
        zone: zone_for(country),
        errors: Array(data["errors"].presence&.values).flatten.map(&:to_s)
      )
    end

    # PostGrid returns the ZIP and its +4 separately. USPS wants ZIP+4 —
    # it's what earns the automation rate — so rejoin them when both are there.
    def postal_code_from(data)
      base = data["postalOrZip"].presence
      return nil if base.nil?

      suffix = (data["zipPlus4"].presence || data["postalCodeSuffix"].presence)
      suffix ? "#{base}-#{suffix}" : base
    end

    # Zone derivation lives here, and only here, because the pricing service
    # consumes it. PostGrid returns lowercase ISO alpha-2 ("us"); our columns
    # hold uppercase. Normalize before comparing or every address is
    # international.
    def zone_for(country_code)
      case country_code.to_s.strip.upcase
      when "US", "USA" then ZONE_US_DOMESTIC
      when "CA", "CAN" then ZONE_CANADA
      else ZONE_INTERNATIONAL
      end
    end
  end
end
