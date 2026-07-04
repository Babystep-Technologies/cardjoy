class AddMaxAdditionalGuestsToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :max_additional_guests, :integer, default: 1
  end
end
