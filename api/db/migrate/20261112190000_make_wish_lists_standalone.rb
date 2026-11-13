# Registry (#245): a wish list no longer has to hang off an invitation. It gets its own owner
# (`user_id`), a public id (`external_id`), and the occasion it is for. Existing lists are
# backfilled from the invitation they belong to, so they keep working untouched.
class MakeWishListsStandalone < ActiveRecord::Migration[8.1]
  def up
    add_reference :wish_lists, :user, foreign_key: true, null: true
    add_column :wish_lists, :external_id, :string
    add_column :wish_lists, :occasion, :string
    add_column :wish_lists, :event_date, :date

    execute(<<~SQL.squish)
      UPDATE wish_lists SET user_id = invitations.user_id
      FROM invitations WHERE invitations.id = wish_lists.invitation_id
    SQL
    select_values("SELECT id FROM wish_lists").each do |id|
      execute("UPDATE wish_lists SET external_id = #{quote(SecureRandom.alphanumeric(10).downcase)} WHERE id = #{id.to_i}")
    end

    change_column_null :wish_lists, :user_id, false
    change_column_null :wish_lists, :external_id, false
    change_column_null :wish_lists, :invitation_id, true
    add_index :wish_lists, :external_id, unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Standalone registries have no invitation to go back to"
  end
end
