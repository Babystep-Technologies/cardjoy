# typed: true

module Mutations
  # Hand credits from an organization's shared pool to one of its members.
  #
  # Admin-gated. The transfer itself lives on Organization#allocate_credits!;
  # this mutation authorizes it, wraps it in the transaction that method's
  # contract requires, and turns its exceptions into a readable errors array.
  class AllocateOrganizationCredits < BaseMutation
    NOT_FOUND_ERROR = "Organization not found"
    USER_NOT_FOUND_ERROR = "User not found"
    NOT_A_MEMBER_ERROR = "User is not a member of this organization"
    INSUFFICIENT_POOL_CREDITS_ERROR = "Not enough credits in the pool"
    INVALID_AMOUNT_ERROR = "Amount must be positive"

    argument :organization_id, ID, required: true
    argument :user_id, ID, required: true
    argument :amount, Integer, required: true

    field :organization, Types::OrganizationType, null: true
    field :member, Types::UserType, null: true
    field :errors, [ String ], null: false

    def resolve(organization_id:, user_id:, amount:)
      current_user = context[:current_user]
      return failure([ NOT_AUTHENTICATED_ERROR ]) unless current_user

      organization = Organization.find_by(id: organization_id)
      return failure([ NOT_FOUND_ERROR ]) unless organization

      # Answering "not authorized" to a non-member keeps a stranger from
      # learning which organization ids exist.
      return failure([ NOT_AUTHORIZED_ERROR ]) unless org_admin?(organization)

      member = User.find_by(id: user_id)
      return failure([ USER_NOT_FOUND_ERROR ]) unless member

      # Checked here as well as in the model so a zero or negative amount comes
      # back as a normal errors array rather than an unhandled ArgumentError.
      return failure([ INVALID_AMOUNT_ERROR ]) unless amount.positive?

      ApplicationRecord.transaction do
        organization.allocate_credits!(user: member, amount: amount, allocated_by: current_user)
      end

      { organization: organization.reload, member: member.reload, errors: [] }
    rescue Organization::NotAMemberError
      failure([ NOT_A_MEMBER_ERROR ])
    rescue Organization::InsufficientPoolCreditsError
      failure([ INSUFFICIENT_POOL_CREDITS_ERROR ])
    end

    private

    def failure(errors)
      { organization: nil, member: nil, errors: errors }
    end
  end
end
