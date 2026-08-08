# typed: true

module Mutations
  # Redeem a join link. Requires authentication: the invitation names an email,
  # and only the person signed in as that email may turn it into a membership.
  #
  # The signed-out half of the flow is Queries::OrganizationInvitationPreview,
  # which lets the join page render before the recipient has an account.
  class AcceptOrganizationInvitation < BaseMutation
    NOT_FOUND_ERROR = "Invitation not found"

    argument :token, String, required: true

    field :membership, Types::OrganizationMembershipType, null: true
    field :organization, Types::OrganizationType, null: true
    field :errors, [ String ], null: false

    def resolve(token:)
      user = context[:current_user]
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless user

      invitation = OrganizationInvitation.find_by(token: token)
      return failure([ NOT_FOUND_ERROR ]) unless invitation

      # Expiry, revocation, and an already-spent token each get their own
      # message — they call for different next steps.
      reason = invitation.unusable_reason
      return failure([ reason ]) if reason

      # Signed in as someone else. Accepting anyway would hand the organization
      # a member it never invited, so this is an error rather than a silent
      # re-address, and the invitation stays pending for its real recipient.
      return failure([ OrganizationInvitation::WRONG_EMAIL_ERROR ]) unless invitation.addressed_to?(user)

      membership = invitation.accept!(user)
      { membership:, organization: membership.organization, errors: [] }
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages)
    end

    private

    def failure(errors)
      { membership: nil, organization: nil, errors: errors }
    end
  end
end
