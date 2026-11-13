# Registry (#248): a guest's claim and their purchase are different things. A claim ("I'm getting
# this") can lapse if nothing happens; a purchase, once the guest says they bought it, cannot.
class AddPurchasedAtToWishListReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_reservations, :purchased_at, :datetime
  end
end
