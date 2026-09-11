class AddStatusUpdatedByAdminToSupportTickets < ActiveRecord::Migration[8.1]
  # Who acted (#173): assignSupportTicket already records itself in
  # assigned_admin_id, but a plain status change had nowhere to record which
  # staff member made it.
  def change
    add_reference :support_tickets, :status_updated_by_admin, null: true, foreign_key: { to_table: :admins }
  end
end
