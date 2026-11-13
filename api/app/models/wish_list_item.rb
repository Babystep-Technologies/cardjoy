# typed: true

class WishListItem < ApplicationRecord
  belongs_to :wish_list
  has_many :reservations, class_name: "WishListReservation", dependent: :destroy

  validates :title, presence: true
  validates :section, length: { maximum: 60 }, allow_nil: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :url, format: { with: %r{\Ahttps?://}, message: "must start with http:// or https://" },
    allow_blank: true

  # A shown price older than this gets a "may have changed" note for guests (#246).
  PRICE_STALE_AFTER = 30.days

  before_validation :normalize_url
  before_validation :normalize_section
  before_save :stamp_price_updated_at, if: :price_changed?
  before_validation :derive_store

  # True when there is a price and it was last set long enough ago that the store may have moved it.
  def price_stale?(now = Time.current)
    return false if price.blank?

    stamped = price_updated_at
    !stamped.nil? && stamped < now - PRICE_STALE_AFTER
  end

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

  def stamp_price_updated_at
    self.price_updated_at = price.present? ? Time.current : nil
  end

  def normalize_section
    self.section = section&.strip.presence
  end

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
