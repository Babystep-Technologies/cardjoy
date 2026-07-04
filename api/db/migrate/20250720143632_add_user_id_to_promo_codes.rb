class AddUserIdToPromoCodes < ActiveRecord::Migration[8.0]
  def change
    add_reference :promo_codes, :user, null: true, foreign_key: true
  end
end
