class AddCreatedAtIndexToOrganizations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # `adminOrganizations` orders by created_at, unindexed until now (#185).
  def change
    add_index :organizations, :created_at, algorithm: :concurrently
  end
end
