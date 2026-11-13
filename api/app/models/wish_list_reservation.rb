# typed: true

# A guest claiming a WishListItem so nobody else duplicates the gift. No account is required to
# reserve: the guest gets a bearer `token` back from the reserve mutation, which is the only way to
# release the reservation later (see Mutations::ReleaseWishListReservation). The token is never
# exposed through any query, only returned once at creation.
class WishListReservation < ApplicationRecord
  belongs_to :wish_list_item

  validates :guest_name, presence: true
  # Required to claim, but scrubbed after the event (WishList::GUEST_EMAIL_RETENTION), so only
  # checked on the way in.
  validates :guest_email, presence: true, on: :create
  validates :guest_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :token, presence: true, uniqueness: true

  # A claim that nobody has bought yet gets a reminder after REMIND_AFTER, and is released
  # RELEASE_AFTER_REMINDER later if it is still unpurchased. A purchase never expires.
  REMIND_AFTER = 14.days
  RELEASE_AFTER_REMINDER = 7.days

  scope :due_for_reminder, -> { unpurchased.where(reminded_at: nil).where(created_at: ..REMIND_AFTER.ago) }
  scope :due_for_release, -> { unpurchased.where(reminded_at: ..RELEASE_AFTER_REMINDER.ago) }
  # Claims on registries whose event has not passed: an archived registry is frozen, so nothing is
  # reminded or released on it (#251).
  scope :on_active_lists, lambda {
    joins(wish_list_item: :wish_list)
      .where("wish_lists.event_date IS NULL OR wish_lists.event_date >= ?", Date.current)
  }
  scope :purchased, -> { where.not(purchased_at: nil) }
  scope :unpurchased, -> { where(purchased_at: nil) }

  before_validation :normalize_email
  before_validation :generate_token, on: :create

  def purchased?
    purchased_at.present?
  end

  private

  def normalize_email
    T.unsafe(self).guest_email = T.unsafe(self).guest_email&.downcase&.strip
  end

  def generate_token
    T.unsafe(self).token ||= SecureRandom.hex(16)
  end
end
