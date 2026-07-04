class CreateSlackUserConnections < ActiveRecord::Migration[8.0]
  def change
    create_table :slack_user_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :slack_user_id, null: false
      t.string :slack_team_id, null: false

      t.timestamps
    end

    add_index :slack_user_connections, [ :slack_user_id, :slack_team_id ], unique: true
  end
end
