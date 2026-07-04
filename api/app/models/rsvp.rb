# typed: true

class Rsvp < ApplicationRecord
  belongs_to :invitation
  belongs_to :user, optional: true

  VALID_STATUSES = %w[going maybe not-going].freeze

  validates :guest_name, presence: true
  validates :guest_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :plus_one_name, presence: true, if: :plus_one?

  # Ensure unique RSVP per email per invitation
  validates :guest_email, uniqueness: { scope: :invitation_id, message: "has already RSVPd to this invitation" }

  before_validation :normalize_email

  scope :going, -> { where(status: "going") }
  scope :maybe, -> { where(status: "maybe") }
  scope :not_going, -> { where(status: "not-going") }

  private

  def normalize_email
    self.guest_email = guest_email&.downcase&.strip
  end
end
