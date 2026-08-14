# typed: true

module Types
  # What the join page may show *before* the recipient signs in.
  #
  # Reachable with nothing but the token, so it is kept to the minimum that
  # makes the page meaningful: which organization, who asked, and whether the
  # link still works. Notably absent are the invited email and the role — a
  # token is guessable-adjacent surface, and neither is needed to decide whether
  # to sign in and accept.
  class OrganizationInvitationPreviewType < Types::BaseObject
    field :organization_name, String, null: false
    field :invited_by_name, String, null: false
    field :valid, Boolean, null: false

    # Why the link no longer works, or null while it does. `valid` alone would
    # leave the join page with one dead-end message for three situations that
    # call for different next steps — ask for a new link, ask to be re-invited,
    # or just sign in, you're already a member. It says nothing a holder of the
    # token couldn't infer by trying to accept.
    field :reason, String, null: true
  end
end
