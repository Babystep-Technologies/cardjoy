class AddDetailsToGuestMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :guest_messages, :details, :jsonb, default: {}
  end
end
