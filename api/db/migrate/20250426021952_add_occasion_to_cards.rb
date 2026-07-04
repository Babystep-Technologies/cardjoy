class AddOccasionToCards < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :occasion, :string
  end
end
