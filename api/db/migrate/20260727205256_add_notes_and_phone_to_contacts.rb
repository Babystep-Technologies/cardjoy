class AddNotesAndPhoneToContacts < ActiveRecord::Migration[8.1]
  def change
    add_column :contacts, :notes, :text
    add_column :contacts, :phone, :string
  end
end
