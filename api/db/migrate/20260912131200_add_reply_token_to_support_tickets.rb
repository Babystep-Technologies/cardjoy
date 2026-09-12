class AddReplyTokenToSupportTickets < ActiveRecord::Migration[8.1]
  # Per-ticket unguessable address (#174): SupportTicketMailer sets `reply_to:
  # support+<reply_token>@...` on every admin reply so a customer's emailed
  # reply threads back onto this ticket instead of landing in a real inbox.
  # Revocable independently of `deleted_at` — same shape as
  # OrganizationInvitation#token / #revoke!.
  def change
    add_column :support_tickets, :reply_token, :string
    add_column :support_tickets, :reply_token_revoked_at, :datetime

    add_index :support_tickets, :reply_token, unique: true
  end
end
