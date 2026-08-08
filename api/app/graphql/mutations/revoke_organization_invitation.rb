# typed: true

module Mutations
  # Withdraw an invitation that hasn't been redeemed yet. The token stops
  # working immediately — that revocability is the reason invitations are
  # persisted rows rather than self-contained signed tokens.
  class RevokeOrganizationInvitation < BaseMutation
    NOT_FOUND_ERROR = "Invitation not found"
    NOT_PENDING_ERROR = "Only a pending invitation can be revoked"

    argument :id, ID, required: true

    field :invitation, Types::OrganizationInvitationType, null: true
    field :errors, [ String ], null: false

    def resolve(id:)
      user = context[:current_user]
      return { invitation: nil, errors: [ NOT_AUTHENTICATED_ERROR ] } unless user

      invitation = OrganizationInvitation.find_by(id: id)
      return { invitation: nil, errors: [ NOT_FOUND_ERROR ] } unless invitation

      # An archived organization reads as nil through the association, and
      # answering "not authorized" there is right: nobody administers it now.
      return { invitation: nil, errors: [ NOT_AUTHORIZED_ERROR ] } unless org_admin?(invitation.organization)

      # Revoking an accepted invitation would suggest it removes the member it
      # created, which it does not.
      return { invitation:, errors: [ NOT_PENDING_ERROR ] } unless invitation.pending?

      invitation.revoke!
      { invitation:, errors: [] }
    end
  end
end
