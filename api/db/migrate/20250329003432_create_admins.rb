class CreateAdmins < ActiveRecord::Migration[8.0]
  def change
    create_table :admins do |t|
      t.string :email
      t.string :name
      t.string :google_uid

      t.timestamps
    end
  end
end
