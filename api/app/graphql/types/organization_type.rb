# typed: true

module Types
  class OrganizationType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :description, String, null: true
    field :members_count, Integer, null: false
    field :credit_balance, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # Email branding (#123). All nullable — nil means this organization's mail
    # uses CardJoy's own branding, which is the default and the common case.
    field :logo_url, String, null: true
    field :accent_color, String, null: true
    field :email_footer_text, String, null: true
    field :email_reply_to, String, null: true

    # The roster (#127). Any member may read it: seeing who else is here is not
    # the same as being able to change it, and the members page renders
    # read-only for a plain member.
    field :memberships, [ Types::OrganizationMembershipType ], null: false

    # Invitations still waiting on a reply. Admin-only, unlike the roster —
    # OrganizationInvitationType names the invited email, and who an admin has
    # approached is not yet the membership list.
    field :pending_invitations, [ Types::OrganizationInvitationType ], null: false

    def members_count
      object.organization_memberships.count
    end

    # Oldest first, so the roster doesn't reshuffle between loads and the
    # founding admins stay at the top where people look for them.
    def memberships
      return [] unless viewer_membership

      object.organization_memberships.includes(:user).order(:created_at, :id)
    end

    # Newest first: the invite an admin just sent is the one they're checking on.
    def pending_invitations
      return [] unless viewer_membership&.admin?

      object.organization_invitations.pending.includes(:invited_by).order(created_at: :desc, id: :desc)
    end

    private

    # Both gates ask the same question, and a page that renders the roster
    # alongside the pending invitations asks it twice in one request.
    def viewer_membership
      return @viewer_membership if defined?(@viewer_membership)

      @viewer_membership = object.membership_for(context[:current_user])
    end
  end
end
