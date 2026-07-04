class AllowTitleOnMessageToBeNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :messages, :title, true
    change_column_null :guest_messages, :title, true
  end
end
