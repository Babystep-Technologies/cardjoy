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

  # Raised by #redeem! when expires_at has passed.
  class ExpiredError < StandardError; end
  # Raised by #redeem! when times_redeemed has reached usage_limit.
  class UsageLimitReachedError < StandardError; end
  # Raised by #redeem! when this user has already redeemed this code. The
  # unique index on promo_code_redemptions(user_id, promo_code_id) is the
  # authoritative guard — this is what a losing concurrent request lands on.
  class AlreadyRedeemedError < StandardError; end

  # Generates a unique, human-friendly code not already in use.
  def self.generate_unique_code
    loop do
      candidate = "cj-#{SecureRandom.alphanumeric(8).downcase}"
      return candidate unless exists?(code: candidate)
    end
  end

  # Grants credit for a single redemption by `user`, returning the credit
  # amount granted. Locks this row for the duration of the transaction (same
  # pattern as User#spend_credit! / Organization#allocate_credits!) so two
  # concurrent redemptions can't both read a stale times_redeemed and both
  # pass the usage_limit check (#186).
  def redeem!(user:)
    transaction do
      lock!

      raise ExpiredError if expires_at&.< Time.current
      raise UsageLimitReachedError if times_redeemed.to_i >= T.must(usage_limit)

      begin
        PromoCodeRedemption.create!(promo_code: self, user: user)
      rescue ActiveRecord::RecordNotUnique
        raise AlreadyRedeemedError
      end

      increment!(:times_redeemed)

      Credit.create!(
        user: user,
        amount: credit_amount,
        reason: "promotion",
        events: [
          {
            event_kind: "promo_code_redeemed",
            event_happened_at: Time.now.utc.iso8601(3),
            event_data: { promo_code: code }
          }
        ]
      )
    end

    credit_amount
  end

  private

  def normalize_code
    self.code = code&.downcase&.strip
  end

  def user_specific?
    user_id.present?
  end
end
