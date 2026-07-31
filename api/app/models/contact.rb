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

  belongs_to :user
  has_many :occasions, dependent: :destroy

  DUPLICATE_MESSAGE = "is already used by another contact"

  before_validation :normalize_phone

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

  private

  # Accept what a human (or a non-CardJoy client) might send — "(415) 555-0123",
  # "+1 415-555-0123" — and reduce it to E.164 so validation and storage stay canonical.
  # Anything still malformed after this falls through to the format validation.
  def normalize_phone
    current = phone
    return if current.nil?

    self.phone = current.gsub(/[\s().\-]/, "")
  end
end
