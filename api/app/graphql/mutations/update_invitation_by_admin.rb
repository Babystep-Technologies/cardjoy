# typed: true

module Mutations
  # Moderation for one invitation (#177).
  #
  # Deliberately identical to Mutations::UpdateCardByAdmin — same argument
  # names, same action vocabulary, same `{ record, errors }` payload — so the
  # admin dashboard drives both products through one component instead of two.
  # Keep the two in step when either grows an action.
  class UpdateInvitationByAdmin < Mutations::BaseMutation
    argument :external_id, String, required: true
    argument :action, String, required: true

    field :invitation, Types::InvitationType, null: true
    field :errors, [ String ], null: false

    VALID_ACTIONS = %w[
      lock unlock
      flag unflag
      archive unarchive
    ].freeze

    def resolve(external_id:, action:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      # Unscoped so `unarchive` can reach an invitation the archive already hid;
      # Invitation is default-scoped to `deleted_at: nil`.
      invitation = Invitation.unscope(where: :deleted_at).find_by(external_id: external_id)
      return { invitation: nil, errors: [ "Invitation not found" ] } unless invitation
      return { invitation: nil, errors: [ "Invalid action" ] } unless VALID_ACTIONS.include?(action)

      begin
        case action
        when "lock"      then invitation.lock!
        when "unlock"    then invitation.unlock!
        when "flag"      then invitation.flag!
        when "unflag"    then invitation.unflag!
        when "archive"   then invitation.delete!
        when "unarchive" then invitation.restore!
        end
      rescue => e
        return { invitation: nil, errors: [ e.message ] }
      end

      { invitation: invitation.reload, errors: [] }
    end
  end
end
