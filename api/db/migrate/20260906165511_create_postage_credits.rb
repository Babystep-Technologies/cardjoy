class CreatePostageCredits < ActiveRecord::Migration[8.1]
  def change
    # The wallet physical mail is charged against (issue #145). Deliberately the
    # same shape as `credits` and `organization_credits` so the three ledgers
    # stay legible side by side — but denominated in US cents, because postage
    # is priced per piece by size and destination and does not divide into whole
    # credits.
    #
    # The column is `amount_cents`, not `amount`: these tables sit next to each
    # other in the schema and in the console, and a bare `amount` meaning
    # dollars in one and cents in another is a bug waiting to happen.
    #
    # `null: false` on the amount, unlike the older two ledgers: a postage row
    # that moves nothing carries no information. See PostageCredit for the
    # matching non-zero validation.
    create_table :postage_credits do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :reason
      t.jsonb :events
      t.string :stripe_session_id

      t.timestamps
    end
  end
end
