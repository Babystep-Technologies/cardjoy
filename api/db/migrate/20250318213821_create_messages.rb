class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.string :title, null: false
      t.text :text, null: false
      t.references :card, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :deleted_at, index: true
      t.datetime :flagged_at

      t.timestamps
    end
  end
end
