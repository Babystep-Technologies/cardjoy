# typed: true
# frozen_string_literal: true

module Mutations
  # Points an invitation at one of the caller's registries, or clears the link with a blank id
  # (#250). Its own mutation so the invitation form's two save paths stay untouched.
  class SetInvitationRegistry < BaseMutation
    argument :invitation_external_id, String, required: true
    argument :registry_external_id, String, required: false

    field :invitation, Types::InvitationType, null: true
    field :errors, [ String ], null: false

    def resolve(invitation_external_id:, registry_external_id: nil)
      user = context[:current_user]
      return failure(NOT_AUTHENTICATED_ERROR) unless user

      invitation = Invitation.find_by(external_id: invitation_external_id)
      return failure("Invitation not found") unless invitation&.editable_by?(user)

      registry = own_registry(registry_external_id)
      return failure("Registry not found") if registry == false || (registry && !registry.standalone?)

      invitation.update!(registry: registry)
      { invitation: invitation.reload, errors: [] }
    end

    private

    def failure(*messages)
      { invitation: nil, errors: messages }
    end
  end
end
