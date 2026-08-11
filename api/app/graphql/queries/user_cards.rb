# typed: true

module Queries
  # The signed-in dashboard list. `organizationId` selects the context: blank
  # lists the user's personal cards, an id lists everything that organization
  # owns (any member sees the same list). A card created inside an organization
  # therefore never shows up in anyone's Personal list, and vice versa.
  class UserCards < BaseQuery
    type [ Types::CardType ], null: true
    argument :user_id, ID, required: true
    argument :organization_id, ID, required: false

    def resolve(user_id:, organization_id: nil)
      return [] unless context[:current_user]

      organization = readable_organization(organization_id)
      return [] if organization == false

      # In an organization context the list is the org's, so `user_id` is not
      # part of the scope — every member sees the same cards.
      return ::Card.in_context(nil, organization) if organization

      user = ::User.find_by(id: user_id)
      return [] unless user

      ::Card.in_context(user, nil)
    end
  end
end
