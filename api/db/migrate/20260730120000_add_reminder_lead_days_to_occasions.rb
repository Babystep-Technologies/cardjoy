class AddReminderLeadDaysToOccasions < ActiveRecord::Migration[8.1]
  # How many days before an occasion its reminder goes out. NULL means the user
  # turned reminders off for that occasion. The default (and the backfill for
  # existing rows) is 7, which is exactly what the reminder engine did when the
  # lead time was a hardcoded constant — so behaviour is unchanged until a user
  # picks something else.
  def change
    add_column :occasions, :reminder_lead_days, :integer, default: 7
  end
end
