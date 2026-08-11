# typed: true
# frozen_string_literal: true

module Queries
  # Fetch a single invitation by its unguessable `external_id`.
  #
  # Like Queries::Card this is a public operation ("GetInvitation" is in
  # GraphqlController::PUBLIC_OPERATIONS) — guests open the invitation and RSVP
  # signed out, and that stays true for an organization-owned invitation.
  #
  # Passing `organizationId` opts into a context-aware read: the invitation must
  # belong to that organization and the caller must be a member of it.
  class Invitation < Queries::BaseQuery
    type Types::InvitationType, null: false
    argument :external_id, String, required: true
    argument :organization_id, ID, required: false

    def resolve(external_id:, organization_id: nil)
      invitation = ::Invitation.find_by!(external_id: external_id)
      return invitation if organization_id.blank?

      organization = readable_organization(organization_id)
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR if organization == false
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless invitation.organization_id == organization&.id

      invitation
    end
  end
end
