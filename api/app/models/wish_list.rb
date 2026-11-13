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

  validates :title, presence: true
  validates :external_id, presence: true, uniqueness: true
  validates :occasion, inclusion: { in: OCCASIONS }, allow_nil: true

  # How far ahead of the event the owner is nudged to share the registry (#251).
  EVENT_REMINDER_LEAD = 14.days

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
    list_items = items.to_a
    reserved = WishListReservation.where(wish_list_item_id: list_items.map(&:id))
    quantities = reserved.group(:wish_list_item_id).sum(:quantity)

    {
      item_count: list_items.size,
      covered_count: list_items.count { |item| quantities.fetch(item.id, 0) >= item.quantity },
      purchased_count: reserved.where.not(purchased_at: nil).count
    }
  end

  def owned_by?(candidate)
    candidate.present? && candidate.id == user_id
  end

  private

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
