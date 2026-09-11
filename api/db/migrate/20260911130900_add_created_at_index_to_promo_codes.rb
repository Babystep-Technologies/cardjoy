class AddCreatedAtIndexToPromoCodes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # `adminPromoCodes` sorts by created_at (and by it as the tiebreaker for
  # every other sort), unindexed until now (#185).
  def change
    add_index :promo_codes, :created_at, algorithm: :concurrently
  end
end
