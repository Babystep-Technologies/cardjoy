# frozen_string_literal: true

# When the host last emailed the RSVPed guests a reminder (#319). Drives the once-a-day limit.
class AddReminderSentAtToInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :invitations, :reminder_sent_at, :datetime
  end
end
