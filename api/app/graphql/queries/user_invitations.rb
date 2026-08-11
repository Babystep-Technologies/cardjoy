# typed: true
# frozen_string_literal: true

module Queries
  # The signed-in dashboard list, mirroring Queries::UserCards: blank
  # `organizationId` lists the user's personal invitations, an id lists
  # everything that organization owns.
  class UserInvitations < Queries::BaseQuery
    type [ Types::InvitationType ], null: false
    argument :user_id, ID, required: true
    argument :organization_id, ID, required: false

    def resolve(user_id:, organization_id: nil)
      return [] unless context[:current_user]

      organization = readable_organization(organization_id)
      return [] if organization == false

      scope =
        if organization
          ::Invitation.in_context(nil, organization)
        else
          ::Invitation.in_context(::User.find(user_id), nil)
        end

      scope.order(created_at: :desc)
    end
  end
end
