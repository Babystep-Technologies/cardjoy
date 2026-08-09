# typed: true

class Credit < ApplicationRecord
  include CreditLedger

  belongs_to :user

  scope :available, -> { where("amount > 0") }

  EVENT_KINDS = %w[
    signup_bonus
    card_created
    invitation_created
    credit_purchased
    credit_redeemed
    promo_code_redeemed
    credit_reversed_due_to_chargeback
  ].freeze

  private

  def allowed_event_kinds
    EVENT_KINDS
  end
end
