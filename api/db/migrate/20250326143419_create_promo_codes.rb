class CreatePromoCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :promo_codes do |t|
      t.string :code
      t.integer :credit_amount
      t.datetime :expires_at
      t.integer :usage_limit
      t.integer :times_redeemed

      t.timestamps
    end
    add_index :promo_codes, :code, unique: true
  end
end
