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

  before_validation :normalize_phone

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: E164_FORMAT, message: "is not a valid phone number" }, allow_blank: true
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
