# typed: true

# A guest claiming a WishListItem so nobody else duplicates the gift. No account is required to
# reserve: the guest gets a bearer `token` back from the reserve mutation, which is the only way to
# release the reservation later (see Mutations::ReleaseWishListReservation). The token is never
# exposed through any query, only returned once at creation.
class WishListReservation < ApplicationRecord
  belongs_to :wish_list_item

  validates :guest_name, presence: true
  validates :guest_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :token, presence: true, uniqueness: true

  before_validation :normalize_email
  before_validation :generate_token, on: :create

  private

  def normalize_email
    T.unsafe(self).guest_email = T.unsafe(self).guest_email&.downcase&.strip
  end

  def generate_token
    T.unsafe(self).token ||= SecureRandom.hex(16)
  end
end
