# When we last tried to re-read an item's price from its link, whether or not that worked, so a
# link that keeps failing can't crowd out the others (#246).
class AddPriceCheckedAtToWishListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_items, :price_checked_at, :datetime
    add_index :wish_list_items, :price_checked_at
  end
end
