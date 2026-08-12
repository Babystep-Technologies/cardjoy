class AddOrganizationToStyles < ActiveRecord::Migration[8.1]
  def change
    # The organization that owns this design asset. NULL means the global
    # curated gallery, which is what every existing row is — so this migration
    # leaves current behaviour completely untouched and needs no backfill.
    #
    # on_delete: :cascade rather than the :nullify that cards/invitations use.
    # An organization's private artwork must not survive the organization by
    # being promoted into the gallery everyone sees. Organizations are normally
    # soft-deleted (Organization#archive!), which this FK never sees.
    add_reference :styles, :organization,
                  null: true,
                  index: true,
                  foreign_key: { to_table: :organizations, on_delete: :cascade }
  end
end
