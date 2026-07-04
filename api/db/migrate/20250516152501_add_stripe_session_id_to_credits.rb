class AddStripeSessionIdToCredits < ActiveRecord::Migration[8.0]
  def change
    add_column :credits, :stripe_session_id, :string
  end
end
