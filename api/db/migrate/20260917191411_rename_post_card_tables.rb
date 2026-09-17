class RenamePostCardTables < ActiveRecord::Migration[8.1]
  def change
    rename_table :holiday_cards, :post_cards
    rename_table :holiday_card_mail_orders, :post_card_mail_orders
    rename_column :post_card_mail_orders, :holiday_card_id, :post_card_id
  end
end
