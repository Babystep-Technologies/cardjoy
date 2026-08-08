class CreateOrganizationMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :organization_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"

      t.timestamps
    end

    # A user belongs to an organization exactly once. Same duplicate-prevention
    # approach as the per-user contact uniqueness added in #110.
    add_index :organization_memberships, [ :organization_id, :user_id ], unique: true
    add_index :organization_memberships, [ :organization_id, :role ]
  end
end
