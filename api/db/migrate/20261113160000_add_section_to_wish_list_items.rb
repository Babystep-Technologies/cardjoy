# A free-text group an owner can file an item under ("Kitchen", "Nursery"), shown as headings on
# the guest page (#246).
class AddSectionToWishListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_items, :section, :string
  end
end
