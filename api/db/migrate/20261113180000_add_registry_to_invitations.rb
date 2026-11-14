# An invitation can point guests at one of its owner's standalone registries (#250), instead of (or
# alongside) the wish list built into the invitation. Deleting the registry just clears the link.
class AddRegistryToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_reference :invitations, :registry, foreign_key: { to_table: :wish_lists, on_delete: :nullify }, index: true
  end
end
