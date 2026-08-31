# typed: true

module Types
  # PostGrid's canonicalized form of an address, returned by
  # `verifyContactAddress` as a *suggestion*.
  #
  # It is never applied automatically. The client shows it beside what the user
  # typed and offers to accept it; people know their own address better than a
  # database does, and silently rewriting "Apt 4B" is how a card goes missing.
  class AddressSuggestionType < Types::BaseObject
    field :address_line1, String, null: true
    field :address_line2, String, null: true
    field :city, String, null: true
    field :region, String, null: true
    field :postal_code, String, null: true
    field :country_code, String, null: true

    # False when PostGrid's canonical form matches what's already stored, so
    # the client can skip the "did you mean…" prompt entirely rather than
    # showing the user their own address back.
    field :differs_from_contact, Boolean, null: false
  end
end
