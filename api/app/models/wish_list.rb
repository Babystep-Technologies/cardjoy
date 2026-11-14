# typed: true

# A registry: the things someone wants, for an occasion, that friends and family can claim. It was
# first built as an invitation's wish list (#95) and is now a product of its own (#243), so it can
# belong to an invitation or stand alone. Either way `user` is the owner.
class WishList < ApplicationRecord
  OCCASIONS = %w[birthday wedding baby housewarming graduation holiday other].freeze

  belongs_to :invitation, optional: true
  belongs_to :user
  has_many :items, -> { order(:position, :id) }, class_name: "WishListItem", dependent: :destroy
  has_many :contributions, -> { order(:position, :id) }, class_name: "WishListContribution", dependent: :destroy

  COVER_IMAGE_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  COVER_IMAGE_MAX_SIZE = 10.megabytes

  has_one_attached :cover_image

  validates :title, presence: true
  validates :cover_image, content_type: { in: COVER_IMAGE_TYPES, message: "must be a PNG, JPEG, GIF or WebP image" },
    size: { less_than: COVER_IMAGE_MAX_SIZE, message: "must be less than 10MB" },
    if: :cover_image_attached?
  validates :external_id, presence: true, uniqueness: true
  validates :occasion, inclusion: { in: OCCASIONS }, allow_nil: true

  # How far ahead of the event the owner is nudged to share the registry (#251).
  EVENT_REMINDER_LEAD = 14.days

  # Guest emails are kept this long past the event, for thank-you notes, then scrubbed (#252).
  GUEST_EMAIL_RETENTION = 7.days

  PASSCODE_MIN_LENGTH = 4
  PASSCODE_ITERATIONS = 100_000

  validate :passcode_long_enough

  before_validation :inherit_owner_from_invitation
  # A new date is a new event, so it earns a fresh reminder.
  before_save :rearm_event_reminder, if: :event_date_changed?
  before_validation :generate_external_id, on: :create

  # Registries whose event is within the lead window, with the owner opted in and not yet reminded.
  # Past events never qualify, so nothing is sent once the event is over.
  def self.due_for_event_reminder(today = Date.current)
    where(remind_owner: true, event_reminded_at: nil, invitation_id: nil)
      .where(event_date: today..(today + EVENT_REMINDER_LEAD))
  end

  # Standalone registries a guest can still claim from: shared, not past their event, and not behind
  # a passcode (nobody is handed a link they can't open).
  scope :open_to_guests, lambda {
    where(visible: true, invitation_id: nil, passcode_digest: nil)
      .where("wish_lists.event_date IS NULL OR wish_lists.event_date >= ?", Date.current)
  }

  # Registries whose event is past the retention window, so their guests' emails are due to go.
  def self.due_for_email_scrub(today = Date.current)
    where(event_date: ..(today - GUEST_EMAIL_RETENTION))
  end

  # An event that has passed archives its registry: still readable, but closed to new claims (#251).
  # With no date there is no event to end, so it never archives.
  def archived?(today = Date.current)
    date = event_date
    !date.nil? && date < today
  end

  def cover_image_url
    return nil unless cover_image.attached?
    # T.unsafe: Sorbet RBI doesn't know about the blob method
    return "#{Rails.configuration.x.cdn_host}/#{T.unsafe(cover_image).blob.key}" if Rails.configuration.x.cdn_enabled

    Rails.application.routes.url_helpers.rails_blob_url(cover_image, only_path: false)
  end

  def empty?
    items.empty? && contributions.empty?
  end

  def standalone?
    invitation_id.nil?
  end

  # Where a guest opens this list, relative to the frontend root.
  def guest_path
    linked_invitation = invitation
    return "/registry/#{external_id}" unless linked_invitation

    "/invitation/#{linked_invitation.external_id}/wishlist"
  end

  # Progress totals for the owner's dashboard: how many items are fully claimed and how many claims
  # are marked bought. Two grouped queries however many items there are.
  def insights
    # Paused items are off the list for now, so they count toward neither total.
    list_items = items.reject(&:paused)
    reserved = WishListReservation.where(wish_list_item_id: list_items.map(&:id))
    quantities = reserved.group(:wish_list_item_id).sum(:quantity)

    {
      item_count: list_items.size,
      covered_count: list_items.count { |item| quantities.fetch(item.id, 0) >= item.quantity },
      purchased_count: reserved.where.not(purchased_at: nil).count
    }
  end

  # Whether the owner may see who gave what, for thank-you notes (#252). Surprise mode hides it until
  # the event is over: with no date it stays hidden, since "over" is unknowable.
  def thank_you_unlocked?
    return true unless surprise_mode

    date = event_date
    !date.nil? && date < Date.current
  end

  # Claims in the order the owner will write the notes: by guest, then by item.
  def thank_you_list
    WishListReservation.joins(:wish_list_item)
      .where(wish_list_items: { wish_list_id: id })
      .includes(:wish_list_item)
      .order(:guest_name, :id)
  end

  # Setting a passcode stores only a salted digest. Blank clears it; too short is a validation error.
  def passcode=(raw)
    value = raw.to_s.strip
    @passcode_too_short = value.present? && value.length < PASSCODE_MIN_LENGTH
    return if @passcode_too_short

    self.passcode_digest = value.empty? ? nil : self.class.digest_passcode(value)
  end

  def passcode_protected?
    passcode_digest.present?
  end

  def passcode_matches?(candidate)
    stored = passcode_digest
    return false if stored.blank? || candidate.blank?

    salt, expected = stored.split("$", 2)
    actual = self.class.pbkdf2(candidate.to_s.strip, [ salt.to_s ].pack("H*"))
    ActiveSupport::SecurityUtils.secure_compare(actual, expected.to_s)
  end

  # Whether this person may open the registry: its owner, anyone when no passcode is set, or a guest
  # who knows it.
  def open_to?(user, passcode)
    owned_by?(user) || !passcode_protected? || passcode_matches?(passcode)
  end

  def self.digest_passcode(value)
    salt = SecureRandom.random_bytes(16)
    "#{salt.unpack1('H*')}$#{pbkdf2(value, salt)}"
  end

  def self.pbkdf2(value, salt)
    OpenSSL::KDF.pbkdf2_hmac(value, salt: salt, iterations: PASSCODE_ITERATIONS, length: 32, hash: "sha256").unpack1("H*")
  end

  def owned_by?(candidate)
    candidate.present? && candidate.id == user_id
  end

  private

  def cover_image_attached?
    cover_image.attached?
  end

  def passcode_long_enough
    errors.add(:passcode, "must be at least #{PASSCODE_MIN_LENGTH} characters") if @passcode_too_short
  end

  def rearm_event_reminder
    self.event_reminded_at = nil
  end

  def inherit_owner_from_invitation
    self.user ||= invitation&.user
  end

  def generate_external_id
    return if external_id.present?

    loop do
      self.external_id = SecureRandom.alphanumeric(10).downcase
      break unless self.class.exists?(external_id: external_id)
    end
  end
end
