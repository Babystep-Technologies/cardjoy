class CreateGuestMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :guest_messages do |t|
      t.references :card, null: false, foreign_key: true
      t.string :name
      t.string :title
      t.text :text
      t.datetime :deleted_at, index: true
      t.datetime :flagged_at

      t.timestamps
    end
  end
end
