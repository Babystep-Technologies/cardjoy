class AddCreatedAtIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # `adminUsers` orders by created_at, and the new-signups count in #183's
  # per-window metrics filters on it (#185). No `user_id` to pair it with here.
  def change
    add_index :users, :created_at, algorithm: :concurrently
  end
end
