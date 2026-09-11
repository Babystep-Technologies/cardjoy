class AddCreatedAtIndexToCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # `cards` has no index on `created_at` at all (#185) — every admin list orders
  # by it, and the admin metrics queries (#183) filter on it per window. The
  # composite covers the common "this owner's cards, newest first" shape
  # (Card.paginated's default order plus a user filter) without a second index;
  # a plain `created_at` index still serves the unfiltered admin list.
  #
  # `algorithm: :concurrently` so this can run against a live database without
  # taking the table lock a normal `add_index` would; that requires
  # `disable_ddl_transaction!` since a concurrent build can't run inside a
  # transaction.
  def change
    add_index :cards, :created_at, algorithm: :concurrently
    add_index :cards, [ :user_id, :created_at ], algorithm: :concurrently
  end
end
