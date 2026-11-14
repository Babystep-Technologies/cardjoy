# An owner can pause an item (sold out, changed their mind) instead of deleting it and its claims
# (#310). Guests see it as no longer available and can't claim it.
class AddPausedToWishListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_items, :paused, :boolean, default: false, null: false
  end
end
