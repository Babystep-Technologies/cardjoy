class AddCreatedAtIndexToHolidayCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Same shape as AddCreatedAtIndexToCards (#185) — holiday cards join the
  # per-product metrics breakdown (#183) for the first time here.
  def change
    add_index :holiday_cards, :created_at, algorithm: :concurrently
    add_index :holiday_cards, [ :user_id, :created_at ], algorithm: :concurrently
  end
end
