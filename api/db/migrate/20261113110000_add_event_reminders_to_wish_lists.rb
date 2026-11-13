# frozen_string_literal: true

# Owner reminders ahead of a registry's event date (#251). `remind_owner` is the opt-out;
# `event_reminded_at` makes the daily job idempotent.
class AddEventRemindersToWishLists < ActiveRecord::Migration[8.1]
  def change
    add_column :wish_lists, :remind_owner, :boolean, default: true, null: false
    add_column :wish_lists, :event_reminded_at, :datetime
  end
end
