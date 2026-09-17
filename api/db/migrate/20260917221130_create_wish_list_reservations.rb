class CreateWishListReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :wish_list_reservations do |t|
      t.references :wish_list_item, null: false, foreign_key: true
      t.string :guest_name, null: false
      t.string :guest_email, null: false
      t.integer :quantity, null: false, default: 1
      t.string :token, null: false

      t.timestamps
    end

    add_index :wish_list_reservations, :token, unique: true
  end
end
