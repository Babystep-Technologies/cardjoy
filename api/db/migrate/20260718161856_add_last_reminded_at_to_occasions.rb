class AddLastRemindedAtToOccasions < ActiveRecord::Migration[8.1]
  def change
    add_column :occasions, :last_reminded_at, :datetime
  end
end
