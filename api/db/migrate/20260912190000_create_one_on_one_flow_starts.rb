class CreateOneOnOneFlowStarts < ActiveRecord::Migration[8.1]
  # One row per time a signed-in user lands on the 1-on-1 create flow (#30's
  # "creation completion rate" numerator's denominator). No session id, no
  # payload — a purpose-built funnel counter, not the general product-event
  # pipeline that issue explicitly keeps out of scope.
  #
  # A brand-new, empty table: its indexes build instantly, so this stays a
  # normal transactional migration (compare add_created_at_index_to_cards.rb,
  # which needed `algorithm: :concurrently` because that table already has
  # rows).
  def change
    create_table :one_on_one_flow_starts do |t|
      t.bigint :user_id, null: false

      t.timestamps
    end

    add_index :one_on_one_flow_starts, [ :user_id, :created_at ]
    add_index :one_on_one_flow_starts, :created_at
    add_foreign_key :one_on_one_flow_starts, :users
  end
end
