class AddCreatedAtAndStripeSessionIndexToOrganizationCredits < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Same reasoning as AddCreatedAtAndStripeSessionIndexToCredits (#185) — the
  # organization pool ledger's own purchase/chargeback lookups and windowed
  # reads had the identical gap.
  def change
    add_index :organization_credits, :created_at, algorithm: :concurrently
    add_index :organization_credits, :stripe_session_id, algorithm: :concurrently
  end
end
