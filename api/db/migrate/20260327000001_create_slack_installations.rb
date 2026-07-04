class CreateSlackInstallations < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_installations do |t|
      t.string :team_id, null: false, index: { unique: true }
      t.string :team_name, null: false
      t.string :access_token, null: false

      t.timestamps
    end
  end
end
