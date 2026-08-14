# typed: true
# frozen_string_literal: true

module Queries
  # Everything the join page can render before the recipient signs in.
  #
  # This is one of the few operations on the PUBLIC_OPERATIONS allowlist in
  # GraphqlController: an invited person may not have an account yet, so the
  # page has to say *something* meaningful while they are still signed out.
  # Accepting still requires authentication — see
  # Mutations::AcceptOrganizationInvitation.
  #
  # Returns null for a token that matches nothing, or whose organization has
  # since been archived. A spent link (accepted, revoked, expired) still
  # resolves, with `valid: false`, so the page can explain what happened rather
  # than showing the same blank wall as a typo'd URL.
  class OrganizationInvitationPreview < Queries::BaseQuery
    type Types::OrganizationInvitationPreviewType, null: true

    argument :token, String, required: true

    def resolve(token:)
      invitation = ::OrganizationInvitation.find_by(token: token)
      return nil if invitation.nil?

      organization = invitation.organization
      return nil if organization.nil?

      {
        organization_name: organization.name,
        invited_by_name: T.must(invitation.invited_by).name,
        valid: invitation.usable?,
        reason: invitation.unusable_reason
      }
    end
  end
end
