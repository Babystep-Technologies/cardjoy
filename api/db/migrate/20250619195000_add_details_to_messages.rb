class AddDetailsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :details, :jsonb, default: {}
  end
end
