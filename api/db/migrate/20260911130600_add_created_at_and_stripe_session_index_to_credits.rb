class AddCreatedAtAndStripeSessionIndexToCredits < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # `created_at` (#185): unindexed, filtered by the metrics queries. Not unique
  # — a Stripe session can, in principle, be retried and looked up more than
  # once before this row lands, and uniqueness is not this index's job.
  # `stripe_session_id` (#185): StripeWebhooksController looks a row up by this
  # on every purchase and chargeback, including the purchase-idempotency
  # `exists?` check — currently a sequential scan every time.
  def change
    add_index :credits, :created_at, algorithm: :concurrently
    add_index :credits, :stripe_session_id, algorithm: :concurrently
  end
end
