class CreateOrganizationCredits < ActiveRecord::Migration[8.1]
  def change
    # Deliberately the same shape as `credits`, keyed on an organization
    # instead of a user, so the two ledgers stay legible side by side.
    create_table :organization_credits do |t|
      t.references :organization, null: false, foreign_key: true
      t.integer :amount
      t.string :reason
      t.jsonb :events
      t.string :stripe_session_id

      t.timestamps
    end
  end
end
