class CreateOrganizationInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_invitations do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false, default: "member"
      t.string :token, null: false
      t.string :status, null: false, default: "pending"
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at

      t.timestamps
    end

    # The token is the credential the join link carries, so it has to resolve to
    # exactly one invitation.
    add_index :organization_invitations, :token, unique: true

    # An invited person looks their invitations up by email — they may not have a
    # user row to join through yet.
    add_index :organization_invitations, :email

    # One live invitation per email per organization. Partial so a revoked or
    # accepted invitation doesn't block re-inviting the same person later, the
    # same duplicate-prevention approach taken for memberships in #110.
    add_index :organization_invitations, [ :organization_id, :email ],
              unique: true,
              where: "status = 'pending'",
              name: "index_organization_invitations_on_org_and_pending_email"
  end
end
