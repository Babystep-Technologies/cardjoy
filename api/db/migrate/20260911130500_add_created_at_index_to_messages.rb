class AddCreatedAtIndexToMessages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Messages join the DAU backfill's source tables (#182) via created_at, which
  # had no index at all (#185).
  def change
    add_index :messages, :created_at, algorithm: :concurrently
  end
end
