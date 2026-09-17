# typed: true

class WishListItem < ApplicationRecord
  belongs_to :wish_list
  has_many :reservations, class_name: "WishListReservation", dependent: :destroy

  validates :title, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :url, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" },
    allow_blank: true

  before_validation :normalize_url
  before_validation :derive_store

  def reserved_quantity
    reservations.sum(:quantity)
  end

  def remaining_quantity
    [ quantity - reserved_quantity, 0 ].max
  end

  def claimed?
    remaining_quantity <= 0
  end

  private

  def normalize_url
    self.url = url&.strip.presence
  end

  # The host is a reasonable stand-in for a store name until link enrichment lands.
  def derive_store
    return if store.present? || url.blank?

    host = URI.parse(T.must(url)).host
    self.store = host&.sub(/\Awww\./, "")
  rescue URI::InvalidURIError
    nil
  end
end
