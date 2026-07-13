class AddKindToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :kind, :string, null: false, default: "group"
  end
end
