# Registry (#248): when a guest was nudged about a claim they have not bought yet, so the claim can
# be released a week later if nothing happens.
class AddRemindedAtToWishListReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_reservations, :reminded_at, :datetime
  end
end
