# When the registry's owner thanked this guest for their gift (#308).
class AddThankedAtToWishListReservations < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_reservations, :thanked_at, :datetime
  end
end
