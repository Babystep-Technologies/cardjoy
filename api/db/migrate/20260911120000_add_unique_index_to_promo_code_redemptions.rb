class AddUniqueIndexToPromoCodeRedemptions < ActiveRecord::Migration[8.1]
  def up
    # Drop any duplicate (user, promo code) redemptions created by the race in
    # #186, keeping the earliest one, before the unique index can be added.
    execute <<~SQL
      DELETE FROM promo_code_redemptions
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM promo_code_redemptions
        GROUP BY user_id, promo_code_id
      )
    SQL

    add_index :promo_code_redemptions, [ :user_id, :promo_code_id ], unique: true
  end

  def down
    remove_index :promo_code_redemptions, [ :user_id, :promo_code_id ]
  end
end
