# typed: true

# A person a user cares about, stored in their occasion book so CardJoy can
# proactively remind them of the person's occasions (birthdays, work
# anniversaries…). Always user-scoped.
class Contact < ApplicationRecord
  # Phone numbers are stored in E.164 ("+14155550123"): a leading "+", a non-zero country
  # code, and up to 15 digits total. The client formats for display; the canonical value is
  # always E.164 so it stays usable for future click-to-call / SMS features.
  E164_FORMAT = /\A\+[1-9]\d{1,14}\z/
  NOTES_MAX_LENGTH = 2000

  # ISO 3166-1 alpha-2 ("US", "GB"), the form every mail vendor we care about speaks.
  COUNTRY_CODE_FORMAT = /\A[A-Z]{2}\z/
  # Every column that makes up the optional mailing address…
  ADDRESS_FIELDS = %i[address_line1 address_line2 city region postal_code country_code].freeze
  # …and the subset a carrier actually needs to deliver something. `region` is out
  # deliberately: plenty of countries have no state/province, and line2 is a suffix.
  REQUIRED_ADDRESS_FIELDS = %i[address_line1 city postal_code country_code].freeze

  INCOMPLETE_ADDRESS_MESSAGE = "is required to complete the mailing address"

  belongs_to :user
  has_many :occasions, dependent: :destroy

  DUPLICATE_MESSAGE = "is already used by another contact"

  before_validation :normalize_phone
  before_validation :normalize_address

  validates :name, presence: true
  # Email and phone are each optional, but when given they identify the person: a user
  # shouldn't be able to save the same person twice and then get two of every reminder.
  # Scoped to the owner, so two users may of course both know the same person.
  validates :email,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            uniqueness: { scope: :user_id, case_sensitive: false, message: DUPLICATE_MESSAGE },
            allow_blank: true
  validates :phone,
            format: { with: E164_FORMAT, message: "is not a valid phone number" },
            uniqueness: { scope: :user_id, message: DUPLICATE_MESSAGE },
            allow_blank: true
  validates :notes, length: { maximum: NOTES_MAX_LENGTH }
  validates :country_code, format: { with: COUNTRY_CODE_FORMAT, message: "is not a valid country code" },
            allow_blank: true
  # A half-filled address is worse than none: it reads as mailable in a list and isn't.
  # So the moment any address field is set, demand the ones delivery actually needs.
  validates(*REQUIRED_ADDRESS_FIELDS,
            presence: { message: INCOMPLETE_ADDRESS_MESSAGE },
            if: :any_address_field?)

  # Whether this contact has enough of an address for a carrier to deliver to it.
  # The predicate the physical-send flow keys on.
  def mailable?
    REQUIRED_ADDRESS_FIELDS.all? { |field| public_send(field).present? }
  end

  private

  # True once the user has typed anything at all into the address, including the
  # optional parts — that's what turns the partial-address validation on.
  def any_address_field?
    ADDRESS_FIELDS.any? { |field| public_send(field).present? }
  end

  # Accept what a human (or a non-CardJoy client) might send — "(415) 555-0123",
  # "+1 415-555-0123" — and reduce it to E.164 so validation and storage stay canonical.
  # Anything still malformed after this falls through to the format validation.
  def normalize_phone
    current = phone
    return if current.nil?

    self.phone = current.gsub(/[\s().\-]/, "")
  end

  # Same spirit as normalize_phone: take what a human typed and store something
  # canonical. Surrounding whitespace goes, a field left blank becomes nil so
  # "cleared" is one value rather than two, and the country code is upper-cased
  # so "us" and "US" are the same country.
  def normalize_address
    ADDRESS_FIELDS.each do |field|
      current = public_send(field)
      next if current.nil?

      stripped = current.strip
      public_send(:"#{field}=", stripped.presence)
    end

    self.country_code = country_code&.upcase
  end
end
