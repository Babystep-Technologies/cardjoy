class AddSlugToCardsAndInvitations < ActiveRecord::Migration[8.0]
  def change
    add_column :cards, :slug, :string
    add_column :invitations, :slug, :string

    add_index :cards, :slug, unique: true, where: "slug IS NOT NULL"
    add_index :invitations, :slug, unique: true, where: "slug IS NOT NULL"
  end
end
