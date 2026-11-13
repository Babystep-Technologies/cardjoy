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

  before_validation :inherit_owner_from_invitation
  before_validation :generate_external_id, on: :create

  def empty?
    items.empty? && contributions.empty?
  end

  def standalone?
    invitation_id.nil?
  end

  def owned_by?(candidate)
    candidate.present? && candidate.id == user_id
  end

  private

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
