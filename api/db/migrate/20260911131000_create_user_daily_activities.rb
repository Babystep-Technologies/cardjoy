class CreateUserDailyActivities < ActiveRecord::Migration[8.1]
  # One row per user per day they made an authenticated request (#182). No
  # event payloads, no session data — just enough to answer "how many distinct
  # users were active on this day", which is what DAU means here.
  #
  # A brand-new, empty table: its own indexes build instantly, so this stays a
  # normal transactional migration rather than needing `algorithm: :concurrently`
  # — unlike the existing tables indexed elsewhere in this PR.
  def change
    create_table :user_daily_activities do |t|
      t.bigint :user_id, null: false
      t.date :activity_date, null: false

      t.timestamps
    end

    add_index :user_daily_activities, [ :user_id, :activity_date ], unique: true,
      name: "index_user_daily_activities_on_user_id_and_activity_date"
    # Serves the aggregate "distinct users per day" read; the write path never
    # needs this one, since it always looks up by the full unique pair above.
    add_index :user_daily_activities, :activity_date
    add_foreign_key :user_daily_activities, :users
  end
end
