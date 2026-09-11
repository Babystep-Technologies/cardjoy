class CreateAnnualGoals < ActiveRecord::Migration[8.1]
  # Server-persisted annual targets (#183), replacing localStorage — every
  # admin was seeing their own goals before this, and the edit dialog said so.
  # One row per calendar year; `year` unique so `setAnnualGoals` can
  # find_or_initialize_by(year:) rather than needing an id passed around.
  def change
    create_table :annual_goals do |t|
      t.integer :year, null: false
      t.integer :dau_target, null: false
      t.integer :cards_and_invitations_target, null: false

      t.timestamps
    end

    add_index :annual_goals, :year, unique: true
  end
end
