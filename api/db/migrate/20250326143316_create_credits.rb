class CreateCredits < ActiveRecord::Migration[8.0]
  def change
    create_table :credits do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount
      t.string :reason
      t.jsonb :metadata

      t.timestamps
    end
  end
end
