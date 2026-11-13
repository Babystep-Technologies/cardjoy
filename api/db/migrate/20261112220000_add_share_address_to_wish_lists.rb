# Registry (#249): whether the owner's mailing address is revealed to guests who claim a gift. Off by
# default; the address itself stays on the user and is never part of a public registry response.
class AddShareAddressToWishLists < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_lists, :share_address, :boolean, default: false, null: false
  end
end
