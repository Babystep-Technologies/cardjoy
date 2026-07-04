class AddOpeningMessageConfigToInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :invitations, :opening_message_config, :jsonb, default: nil
  end
end
