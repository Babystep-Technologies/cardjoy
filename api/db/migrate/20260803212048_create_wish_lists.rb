class CreateWishLists < ActiveRecord::Migration[8.1]
  def change
    create_table :wish_lists do |t|
      t.references :invitation, null: false, foreign_key: true, index: { unique: true }
      t.string :title, null: false, default: "Wish List"
      t.text :intro
      t.boolean :visible, null: false, default: true
      t.boolean :surprise_mode, null: false, default: true

      t.timestamps
    end

    create_table :wish_list_items do |t|
      t.references :wish_list, null: false, foreign_key: true
      t.string :title, null: false
      t.string :url
      t.string :image_url
      t.string :price
      t.string :store
      t.text :note
      t.integer :quantity, null: false, default: 1
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    create_table :wish_list_contributions do |t|
      t.references :wish_list, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :handle, null: false
      t.string :label
      t.string :suggested_amount
      t.text :note
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :wish_list_items, [ :wish_list_id, :position ]
    add_index :wish_list_contributions, [ :wish_list_id, :position ]
  end
end
