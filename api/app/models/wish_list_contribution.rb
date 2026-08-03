# typed: true

# A cash-gift destination on a wish list.
#
# COMPLIANCE: these records only ever store a handle or URL pointing at the *host's own* payment
# account. CardJoy links out to the payment app and never holds, moves, splits or refunds funds,
# which is what keeps it out of money-transmitter and PCI scope. Do not add in-app processing here
# without legal review — see issue #95.
class WishListContribution < ApplicationRecord
  VENMO = "venmo"
  CASHAPP = "cashapp"
  PAYPAL = "paypal"
  ZELLE = "zelle"
  TRUMP_ACCOUNT = "trump_account"

  KINDS = [ VENMO, CASHAPP, PAYPAL, ZELLE, TRUMP_ACCOUNT ].freeze

  # Zelle has no public deep link, and a Trump Account is funded through the child's custodian,
  # so both are display-and-copy only.
  LINKABLE_KINDS = [ VENMO, CASHAPP, PAYPAL ].freeze

  belongs_to :wish_list

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :handle, presence: true

  before_validation :normalize_handle

  def linkable?
    LINKABLE_KINDS.include?(kind)
  end

  # A URL that opens the host's account in the payment app, or nil when the kind has no deep link
  # and the guest has to send manually.
  def action_url
    return nil unless linkable?
    return handle if handle.to_s.start_with?("http://", "https://")

    bare = handle.to_s.delete_prefix("@").delete_prefix("$")
    return nil if bare.blank?

    case kind
    when VENMO then "https://venmo.com/u/#{bare}"
    when CASHAPP then "https://cash.app/$#{bare}"
    when PAYPAL then "https://paypal.me/#{bare.delete_prefix('paypal.me/')}"
    end
  end

  private

  # Leaves a blank handle blank rather than nil so the presence validation reports it.
  def normalize_handle
    self.handle = handle.strip if handle.is_a?(String)
  end
end
