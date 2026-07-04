class CreateRsvps < ActiveRecord::Migration[8.0]
  def change
    create_table :rsvps do |t|
      t.references :invitation, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :guest_name
      t.string :guest_email
      t.string :status
      t.boolean :plus_one
      t.string :plus_one_name
      t.text :message

      t.timestamps
    end
  end
end
