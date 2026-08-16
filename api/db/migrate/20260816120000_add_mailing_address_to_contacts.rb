class AddMailingAddressToContacts < ActiveRecord::Migration[8.1]
  def change
    # A contact has at most one mailing address, so it lives on the contact row
    # rather than in an addresses table. Every column is nullable: an address is
    # optional and most contacts will never have one. `region` rather than
    # `state`, which is meaningless outside the US; `country_code` is ISO 3166-1
    # alpha-2, upper-cased on write by Contact.
    add_column :contacts, :address_line1, :string
    add_column :contacts, :address_line2, :string
    add_column :contacts, :city, :string
    add_column :contacts, :region, :string
    add_column :contacts, :postal_code, :string
    add_column :contacts, :country_code, :string
  end
end
