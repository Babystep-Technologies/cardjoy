# frozen_string_literal: true

# "Most wanted" marker on a registry item (#246), so the owner can tell guests what matters most.
class AddPriorityToWishListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_list_items, :priority, :boolean, default: false, null: false
  end
end
