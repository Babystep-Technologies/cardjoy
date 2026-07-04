class AddOpeningMessageToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :opening_message, :string
  end
end
