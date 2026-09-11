class AddCreatedAtAndStatusIndexToRsvps < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # `created_at` (#185): the RSVP counts in both businessMetrics and the new
  # per-window metrics (#183) filter on it. `status` (#185): businessMetrics
  # already runs Rsvp.going/.maybe/.not_going against this column with no index
  # at all.
  def change
    add_index :rsvps, :created_at, algorithm: :concurrently
    add_index :rsvps, :status, algorithm: :concurrently
  end
end
