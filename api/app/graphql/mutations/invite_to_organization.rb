# typed: true

module Mutations
  # Invite one or more email addresses to join an organization.
  #
  # A batch is not all-or-nothing. Pasting a list of colleagues almost always
  # includes people who are already in, so an address that already has a pending
  # invitation or a membership is reported in `skippedEmails` and the rest still
  # go out. `errors` is reserved for things the caller must fix.
  class InviteToOrganization < BaseMutation
    INVALID_ROLE_ERROR = "Role must be admin or member"
    NO_EMAILS_ERROR = "Enter at least one email address"

    argument :organization_id, ID, required: true
    argument :emails, [ String ], required: true
    argument :role, String, required: false

    field :invitations, [ Types::OrganizationInvitationType ], null: false
    field :skipped_emails, [ String ], null: false
    field :errors, [ String ], null: false

    def resolve(organization_id:, emails:, role: OrganizationMembership::MEMBER)
      user = context[:current_user]
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless user

      organization = Organization.find_by(id: organization_id)
      return failure([ "Organization not found" ]) unless organization
      return failure([ NOT_AUTHORIZED_ERROR ]) unless org_admin?(organization)
      return failure([ INVALID_ROLE_ERROR ]) unless OrganizationMembership::ROLES.include?(role)

      addresses = normalize(emails)
      return failure([ NO_EMAILS_ERROR ]) if addresses.empty?

      invite(organization, addresses, role:, invited_by: user)
    end

    private

    def failure(errors)
      { invitations: [], skipped_emails: [], errors: errors }
    end

    # Downcased to match how OrganizationInvitation stores them, and deduped so
    # the same address listed twice doesn't trip the partial unique index and
    # come back as a validation error.
    def normalize(emails)
      emails.map { |email| email.to_s.strip.downcase }.reject(&:blank?).uniq
    end

    def invite(organization, addresses, role:, invited_by:)
      taken = already_invited_or_joined(organization, addresses)

      invitations = []
      skipped = []
      errors = []

      addresses.each do |email|
        if taken.include?(email)
          skipped << email
          next
        end

        invitation = organization.organization_invitations.build(email:, role:, invited_by:)

        if invitation.save
          OrganizationMailer.invitation(invitation).deliver_later
          invitations << invitation
        else
          errors.concat(invitation.errors.full_messages.map { |message| "#{email}: #{message}" })
        end
      end

      { invitations:, skipped_emails: skipped, errors: }
    end

    # Addresses that need no new invitation: an outstanding one already covers
    # them, or they are in the organization already.
    def already_invited_or_joined(organization, addresses)
      pending = organization.organization_invitations.pending.where(email: addresses).pluck(:email)
      members = organization.users.where("LOWER(email) IN (?)", addresses).pluck(:email).map(&:downcase)

      (pending + members).to_set
    end
  end
end
