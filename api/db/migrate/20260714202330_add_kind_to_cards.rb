class AddKindToCards < ActiveRecord::Migration[8.1]
  def change
    add_column :cards, :kind, :string, null: false, default: "group"
  end
end
