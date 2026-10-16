class AddReturnAddressToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :return_address_line1, :string
    add_column :users, :return_address_line2, :string
    add_column :users, :return_address_city, :string
    add_column :users, :return_address_region, :string
    add_column :users, :return_address_postal_code, :string
    add_column :users, :return_address_country_code, :string
  end
end
