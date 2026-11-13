# When an item's price was last set, so guests can be told a price may have changed (#246).
class AddPriceUpdatedAtToWishListItems < ActiveRecord::Migration[8.1]
  def up
    add_column :wish_list_items, :price_updated_at, :datetime
    # An existing price is as fresh as the row was last touched.
    execute "UPDATE wish_list_items SET price_updated_at = updated_at WHERE price IS NOT NULL AND price <> ''"
  end

  def down
    remove_column :wish_list_items, :price_updated_at
  end
end
