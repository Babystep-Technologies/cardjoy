class AddSourceOccasionToCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Attribution for #30's "reminder to card conversion" metric: which 1-on-1
  # card, if any, a card traces back to the occasion-reminder deep link
  # (OccasionReminderMailer#create_flow_url). Nullable and best-effort — most
  # cards have no reminder behind them at all, and the column is metadata
  # only, never used for authorization.
  #
  # `on_delete: :nullify` rather than `:cascade`: deleting an occasion (or its
  # contact) must not destroy a card someone already sent, only forget which
  # occasion it came from.
  #
  # The column starts all-NULL, so add_foreign_key's existing-row check is
  # instant regardless of table size — no need for the validate:false /
  # validate_foreign_key split a backfilled FK would need. Only the index
  # build needs `algorithm: :concurrently`, since `cards` already has rows.
  def change
    add_column :cards, :source_occasion_id, :bigint
    add_index :cards, :source_occasion_id, algorithm: :concurrently
    add_foreign_key :cards, :occasions, column: :source_occasion_id, on_delete: :nullify
  end
end
