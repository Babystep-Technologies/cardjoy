class CreateHolidayCards < ActiveRecord::Migration[8.1]
  def change
    # A holiday card is a printed piece with a front and a back, so it does not
    # reuse `cards` (a single surface plus a list of messages). `design_config`
    # holds the whole design document; the slot geometry it fills lives in the
    # static template catalogue, not here.
    create_table :holiday_cards do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :title
      t.string :size, null: false, default: "6x4"
      t.string :template_id, null: false
      t.jsonb :design_config, null: false, default: {}
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :holiday_cards, :external_id, unique: true
    add_index :holiday_cards, :deleted_at
  end
end
