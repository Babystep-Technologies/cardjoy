# typed: true

class PromoCode < ApplicationRecord
  belongs_to :user, optional: true
  has_many :promo_code_redemptions, dependent: :destroy

  before_validation :normalize_code

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :credit_amount, numericality: { only_integer: true, greater_than: 0 }
  validates :usage_limit, numericality: { only_integer: true, greater_than: 0 }
  # Validation: user-specific promo codes can only be used once
  validates :usage_limit, inclusion: { in: [ 1 ] }, if: :user_specific?

  # Generates a unique, human-friendly code not already in use.
  def self.generate_unique_code
    loop do
      candidate = "cj-#{SecureRandom.alphanumeric(8).downcase}"
      return candidate unless exists?(code: candidate)
    end
  end

  private

  def normalize_code
    self.code = code&.downcase&.strip
  end

  def user_specific?
    user_id.present?
  end
end
