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

  # Cached PostGrid verification, cleared by #clear_address_verification the
  # moment the address moves under it.
  VERIFICATION_FIELDS = %i[address_verified_at address_verification_status address_zone].freeze

  VERIFIED_STATUS = "verified"
  UNDELIVERABLE_STATUS = "undeliverable"
  # Never stored — it's what a nil `address_verification_status` *means*, and
  # what #address_verification_state reports so the client always has one of
  # three strings instead of a null it has to interpret.
  UNVERIFIED_STATUS = "unverified"

  belongs_to :user
  has_many :occasions, dependent: :destroy
  # Deleting a contact must not leave a membership row pointing at nothing, so
  # the join rows go with it. The lists themselves survive.
  has_many :contact_list_memberships, dependent: :destroy
  has_many :contact_lists, through: :contact_list_memberships
  # Nullified, never destroyed. An order is a record of money spent and of a
  # card that is physically in the post; deleting the contact must not erase it.
  # `recipient_snapshot` is what keeps the order readable afterwards.
  has_many :holiday_card_mail_orders, dependent: :nullify

  # The SQL form of #mailable?, for callers that want to count or filter without
  # loading every row (see ContactList#mailable_contacts_count).
  scope :mailable, -> {
    REQUIRED_ADDRESS_FIELDS.reduce(all) { |relation, field| relation.where.not(field => [ nil, "" ]) }
  }

  DUPLICATE_MESSAGE = "is already used by another contact"

  before_validation :normalize_phone
  before_validation :normalize_address
  # In a callback, not in the mutation, so *every* path is covered — the
  # mutations, the console, an importer, a future bulk edit. A verified badge
  # that outlives the address it verified is worse than no badge at all: it is
  # the user's cue to stop checking, on the one field that decides whether the
  # card arrives.
  before_save :clear_address_verification, if: :address_changing?

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

  # The verification verdict as one of three strings. A nil column means the
  # address has never been verified, or an edit invalidated the result — both
  # are "unverified" to a caller, so collapse them here rather than making
  # every client special-case null.
  def address_verification_state
    address_verification_status.presence || UNVERIFIED_STATUS
  end

  # Whether the cached verdict says a carrier will deliver to this address.
  def address_verified?
    address_verification_status == VERIFIED_STATUS
  end

  # Persist a PostGrid::AddressVerification::Result. Writes only the cache
  # columns — never the address itself, so the user's own wording survives and
  # #clear_address_verification isn't triggered by our own write.
  def apply_address_verification!(result)
    update!(
      address_verified_at: Time.current,
      address_verification_status: result.deliverable? ? VERIFIED_STATUS : UNDELIVERABLE_STATUS,
      address_zone: result.zone
    )
  end

  private

  # True when this save changes any address field. Guards the invalidation
  # callback so writing the verification columns themselves — which is what
  # #apply_address_verification! does moments after a successful verify —
  # doesn't immediately wipe what it just wrote.
  def address_changing?
    ADDRESS_FIELDS.any? { |field| public_send(:"#{field}_changed?") }
  end

  def clear_address_verification
    VERIFICATION_FIELDS.each { |field| public_send(:"#{field}=", nil) }
  end

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
