class CreateSupportTickets < ActiveRecord::Migration[8.1]
  # The persistence layer support has never had (issue #172). Today a "support
  # request" is one outbound email with no ticket id, no status, and no record
  # that a customer ever contacted us — this table is that record. The admin
  # inbox (#173) sorts on `status` and `last_customer_reply_at`; the reply
  # thread lives in support_ticket_messages, created alongside this migration.
  def change
    create_table :support_tickets do |t|
      t.references :user, null: false, foreign_key: true

      # The id used in URLs and in email subjects — never the database id, the
      # same reasoning as Card and HolidayCard's external_id.
      t.string :external_id, null: false

      t.string :subject, null: false
      t.string :category, null: false

      # Ours: open (needs a staff reply), pending (waiting on the customer),
      # resolved, closed. See SupportTicket::STATUSES.
      t.string :status, null: false

      # Drive the inbox sort in #173: staff wants tickets nobody has answered
      # first, and a customer's own reply is what turns pending back into open.
      t.datetime :last_customer_reply_at
      t.datetime :last_admin_reply_at

      t.references :assigned_admin, null: true, foreign_key: { to_table: :admins }

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :support_tickets, :external_id, unique: true
    add_index :support_tickets, [ :user_id, :created_at ]
    add_index :support_tickets, [ :status, :last_customer_reply_at ]
  end
end
