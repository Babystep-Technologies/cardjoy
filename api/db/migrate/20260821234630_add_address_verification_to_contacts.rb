class AddAddressVerificationToContacts < ActiveRecord::Migration[8.1]
  # Cached PostGrid address-verification results (issue #142).
  #
  # These are a cache, not a source of truth, which is why every column is
  # nullable: nil means "never verified, or invalidated by an edit". Contact
  # clears all three whenever an address field changes, so a corrected address
  # cannot keep a stale "verified" badge.
  #
  # `address_zone` is the load-bearing one. PostGrid has no price-quote
  # endpoint, so a card's cost is a rate-card lookup on size × class ×
  # destination zone; verification is the only place the zone comes from.
  def change
    add_column :contacts, :address_verified_at, :datetime
    add_column :contacts, :address_verification_status, :string
    add_column :contacts, :address_zone, :string
  end
end
