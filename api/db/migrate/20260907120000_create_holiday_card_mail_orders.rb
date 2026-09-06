class CreateHolidayCardMailOrders < ActiveRecord::Migration[8.1]
  def change
    # One row per **physical piece**, not per send (issue #148). Forty cards to
    # forty people is forty rows: each one gets its own PostGrid id, its own
    # status, its own tracking number, and can fail and refund without touching
    # the other thirty-nine. Atomicity across an external print service is not
    # achievable, so the schema admits it rather than pretending.
    create_table :holiday_card_mail_orders do |t|
      t.references :holiday_card, null: false, foreign_key: true
      # Denormalized from the card so a user's orders are queryable without a
      # join, and so an order survives as a billing record independent of the
      # card's own lifecycle.
      t.references :user, null: false, foreign_key: true
      # Nullable on purpose. The contact is a *live* reference the user may edit
      # or delete after the card is in the mail; `recipient_snapshot` below is
      # the fact of where it went. `nullify` rather than `cascade`: deleting a
      # contact must never delete the record of money spent mailing to them.
      t.references :contact, null: true, foreign_key: { on_delete: :nullify }

      # Name and address exactly as they were at send time. The address printed
      # on a card is history, not a live lookup — support, the user's own order
      # list, and any refund conversation all need what we actually sent.
      t.jsonb :recipient_snapshot, null: false, default: {}

      # What was priced, and under which rate card. Stored rather than
      # recomputed: rates change, and "why was I charged 112¢?" has a right
      # answer only if the inputs to that number are still here in March.
      t.string :size, null: false
      t.string :mailing_class, null: false
      t.string :zone, null: false
      t.string :rate_card_version, null: false
      t.integer :base_cents, null: false
      t.integer :charged_cents, null: false

      # The negative postage_credits row this piece was charged against, so a
      # refund can be traced back to exactly what it reverses.
      t.references :postage_credit, null: true, foreign_key: true

      t.string :postgrid_id

      # What makes a retry safe: PostGrid returns the original postcard for a
      # repeated key rather than printing a second one. Generated once when the
      # order is created and never regenerated — a key minted per attempt would
      # mail the card twice. Unique so a bug that reused one is a constraint
      # violation rather than a duplicate print.
      t.string :idempotency_key, null: false

      # Ours, not PostGrid's — see HolidayCardMailOrder::STATUSES.
      t.string :status, null: false
      t.string :tracking_number
      t.text :failure_reason

      t.datetime :submitted_at
      t.datetime :mailed_at

      t.timestamps
    end

    add_index :holiday_card_mail_orders, :idempotency_key, unique: true
    add_index :holiday_card_mail_orders, :postgrid_id
    add_index :holiday_card_mail_orders, :status
  end
end
