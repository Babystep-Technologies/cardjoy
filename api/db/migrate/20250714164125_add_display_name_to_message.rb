class AddDisplayNameToMessage < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :display_name, :string
  end
end
