class CreateInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :invitations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id
      t.string :title
      t.text :description
      t.string :location
      t.date :event_date
      t.string :event_time
      t.string :event_timezone
      t.date :rsvp_deadline
      t.boolean :allow_plus_one
      t.string :attire
      t.text :custom_instructions

      t.timestamps
    end
    add_index :invitations, :external_id, unique: true
  end
end
