class CreateContactLists < ActiveRecord::Migration[8.1]
  def change
    # A named, reusable group of the user's contacts — "the 2026 card list",
    # "Marshall's side of the family". Lists are user-scoped like contacts
    # themselves; a list is never shared across users.
    create_table :contact_lists do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    # One "Family" per user. Two users may of course both have one, which is
    # why this is scoped rather than a plain unique index on `name`.
    add_index :contact_lists, [ :user_id, :name ], unique: true

    # The join. Both sides are user-scoped records and nothing here stops a row
    # pairing one user's list with another user's contact — that is enforced by
    # ContactListMembership's validation, which is the only place it can be.
    create_table :contact_list_memberships do |t|
      t.references :contact_list, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true

      t.timestamps
    end

    # A contact is on a list once. Backs the idempotency addContactsToList
    # promises, so a concurrent double-add can't slip two rows past the
    # model-level check.
    add_index :contact_list_memberships, [ :contact_list_id, :contact_id ], unique: true
  end
end
