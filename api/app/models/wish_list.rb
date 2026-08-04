# typed: true

class WishList < ApplicationRecord
  belongs_to :invitation
  has_many :items, -> { order(:position, :id) }, class_name: "WishListItem", dependent: :destroy
  has_many :contributions, -> { order(:position, :id) }, class_name: "WishListContribution", dependent: :destroy

  validates :title, presence: true

  def empty?
    items.empty? && contributions.empty?
  end
end
