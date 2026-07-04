class AddRequireLoginToContributeToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :require_login_to_contribute, :boolean, default: false, null: false
  end
end
