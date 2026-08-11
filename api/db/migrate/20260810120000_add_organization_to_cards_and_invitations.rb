class AddOrganizationToCardsAndInvitations < ActiveRecord::Migration[8.1]
  def change
    # The organization that owns this card/invitation. NULL means personal,
    # which is what every existing row is — so this migration leaves current
    # behaviour completely untouched and needs no backfill.
    #
    # on_delete: :nullify mirrors users.active_organization_id: a hard-deleted
    # organization must not leave rows pointing at nothing. Organizations are
    # normally soft-deleted (Organization#archive!), which this FK never sees;
    # an archived org's cards keep their organization_id and degrade to
    # owner-only access (see OrganizationScoped).
    add_reference :cards, :organization,
                  null: true,
                  index: true,
                  foreign_key: { to_table: :organizations, on_delete: :nullify }

    add_reference :invitations, :organization,
                  null: true,
                  index: true,
                  foreign_key: { to_table: :organizations, on_delete: :nullify }
  end
end
