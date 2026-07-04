class CreateCards < ActiveRecord::Migration[8.0]
  def change
    create_table :cards do |t|
      t.string :external_id, null: false, index: { unique: true }
      t.string :title
      t.jsonb :recipients, default: [], null: false
      t.references :user, null: false, foreign_key: true
      t.datetime :flagged_at
      t.datetime :locked_at
      t.datetime :deleted_at, index: true
      t.integer :max_messages, default: 20, null: false

      t.timestamps
    end
  end
end
