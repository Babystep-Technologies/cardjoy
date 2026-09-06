# typed: true

module Types
  # The address a piece of mail was sent to, exactly as it stood when it was
  # sent (#148).
  #
  # A separate type rather than a JSON scalar so the client gets named,
  # typed fields it can render — and so `recipient_snapshot`'s storage shape
  # stays free to change without every consumer parsing a blob differently.
  #
  # Resolved from the snapshot hash, so every field is nullable: an order mailed
  # to an address with no `region` has no region, and there is no contact to
  # fall back to.
  class HolidayCardMailRecipientType < Types::BaseObject
    description "A recipient's name and address, frozen at the moment the card was sent."

    field :name, String, null: true
    field :address_line1, String, null: true
    field :address_line2, String, null: true
    field :city, String, null: true
    field :region, String, null: true
    field :postal_code, String, null: true
    field :country_code, String, null: true

    # The snapshot is a plain hash with string keys, which GraphQL-Ruby's
    # default resolver would try to read as methods. Written out rather than
    # generated in a loop so both a reader and Sorbet can see them.
    def name = object["name"]
    def address_line1 = object["address_line1"]
    def address_line2 = object["address_line2"]
    def city = object["city"]
    def region = object["region"]
    def postal_code = object["postal_code"]
    def country_code = object["country_code"]
  end
end
