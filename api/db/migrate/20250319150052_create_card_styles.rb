class CreateCardStyles < ActiveRecord::Migration[8.0]
  def change
    create_table :card_styles do |t|
      t.references :card, null: false, foreign_key: true
      t.references :style, null: false, foreign_key: true

      t.timestamps
    end
  end
end
