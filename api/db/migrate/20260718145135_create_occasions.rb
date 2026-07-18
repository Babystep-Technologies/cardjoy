class CreateOccasions < ActiveRecord::Migration[8.1]
  def change
    create_table :occasions do |t|
      t.references :contact, null: false, foreign_key: true
      t.string :kind, null: false
      t.date :occurs_on, null: false
      t.boolean :recurring, null: false, default: true

      t.timestamps
    end

    add_index :occasions, :occurs_on
  end
end
