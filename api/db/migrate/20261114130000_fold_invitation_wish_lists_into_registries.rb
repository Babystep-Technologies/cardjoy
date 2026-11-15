# frozen_string_literal: true

# An invitation no longer owns a wish list; it links a registry (`invitations.registry_id`). This
# turns every existing invitation wish list into a registry of its owner's and, where the invitation
# had no registry linked, links it, so guests still find the same list from the invitation.
#
# - Empty lists (nothing added) are deleted: they were created by opening the editor.
# - The registry takes the invitation's event date, so it archives and scrubs guest emails on the
#   same schedule as before, and is marked as already reminded so converting it sends the owner no
#   "share your registry" nudge about an event they already invited people to.
# - A list still called "Wish List" is renamed after the invitation.
#
# One-way: after this, the original invitation link is gone, so `down` only restores the column.
class FoldInvitationWishListsIntoRegistries < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      DELETE FROM wish_lists
      WHERE invitation_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM wish_list_items i WHERE i.wish_list_id = wish_lists.id)
        AND NOT EXISTS (SELECT 1 FROM wish_list_contributions c WHERE c.wish_list_id = wish_lists.id)
    SQL

    execute <<~SQL.squish
      UPDATE invitations
      SET registry_id = wl.id
      FROM wish_lists wl
      WHERE wl.invitation_id = invitations.id AND invitations.registry_id IS NULL
    SQL

    execute <<~SQL.squish
      UPDATE wish_lists
      SET title = CASE WHEN wish_lists.title = 'Wish List' THEN inv.title ELSE wish_lists.title END,
          event_date = COALESCE(wish_lists.event_date, inv.event_date),
          event_reminded_at = COALESCE(wish_lists.event_reminded_at, now())
      FROM invitations inv
      WHERE wish_lists.invitation_id = inv.id
    SQL

    remove_index :wish_lists, :invitation_id
    remove_column :wish_lists, :invitation_id
  end

  def down
    add_column :wish_lists, :invitation_id, :bigint
    add_index :wish_lists, :invitation_id, unique: true
  end
end
