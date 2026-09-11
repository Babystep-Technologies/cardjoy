class AddCreatedAtIndexToInvitations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Same shape as AddCreatedAtIndexToCards (#185): the admin invitations list
  # orders by created_at, and the per-user, per-window queries filter on both.
  def change
    add_index :invitations, :created_at, algorithm: :concurrently
    add_index :invitations, [ :user_id, :created_at ], algorithm: :concurrently
  end
end
