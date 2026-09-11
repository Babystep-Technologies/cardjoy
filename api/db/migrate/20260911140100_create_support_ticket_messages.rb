class CreateSupportTicketMessages < ActiveRecord::Migration[8.1]
  # The reply thread for a SupportTicket (issue #172). `author_id` is
  # deliberately not a `belongs_to :author` foreign key: User and Admin are
  # separate models with separate id spaces, so a customer message's
  # `author_id` and an admin message's `author_id` point at different tables
  # and only `author_kind` says which. `inbound_email_id` stays nullable and
  # unpopulated until #174 wires up mail-in replies.
  def change
    create_table :support_ticket_messages do |t|
      t.references :support_ticket, null: false, foreign_key: true

      # "customer" / "admin" / "system". See SupportTicketMessage::AUTHOR_KINDS.
      t.string :author_kind, null: false
      # A User id when author_kind is "customer", an Admin id when "admin", null
      # for "system" — never a foreign key, for the reason above.
      t.bigint :author_id

      t.text :body, null: false

      # Populated by #174 when a message arrives by email rather than through
      # the customer-facing mutation or the admin inbox.
      t.string :inbound_email_id

      t.datetime :deleted_at

      t.timestamps
    end

    add_index :support_ticket_messages, [ :support_ticket_id, :created_at ]
  end
end
