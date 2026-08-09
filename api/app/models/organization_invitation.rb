# typed: true

# A pending offer of membership in an Organization, addressed to an email rather
# than to a User: the invited person may not have a CardJoy account yet.
#
# That detour is why `token` is a persisted random string and not a JWT like the
# Slack and password-reset links. The token has to survive a sign-up round trip,
# stay revocable, and be single-use — none of which a stateless token gives us.
class OrganizationInvitation < ApplicationRecord
  extend T::Sig

  PENDING = "pending"
  ACCEPTED = "accepted"
  REVOKED = "revoked"
  STATUSES = [ PENDING, ACCEPTED, REVOKED ].freeze

  # How long a join link stays usable. Long enough to survive a vacation, short
  # enough that a leaked link stops working.
  EXPIRES_IN = 14.days

  TOKEN_BYTES = 32

  # Surfaced to the person clicking the join link, so each dead end reads
  # differently — "expired" and "revoked" call for different next steps.
  EXPIRED_ERROR = "This invitation has expired"
  REVOKED_ERROR = "This invitation has been revoked"
  ALREADY_ACCEPTED_ERROR = "This invitation has already been accepted"
  WRONG_EMAIL_ERROR = "This invitation was sent to a different email address"

  belongs_to :organization
  belongs_to :invited_by, class_name: "User"

  before_validation :normalize_email
  before_validation :assign_token, on: :create
  before_validation :assign_expiry, on: :create

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # Mirrors the partial unique index: one live invitation per email per
  # organization, while a spent one leaves the address free to be invited again.
  # The index is the real guarantee; this exists so a caller gets an errors
  # array instead of a RecordNotUnique.
  validates :email,
            uniqueness: {
              scope: :organization_id,
              conditions: -> { where(status: PENDING) },
              message: "already has a pending invitation to this organization"
            },
            if: :pending?

  validates :role, presence: true, inclusion: { in: OrganizationMembership::ROLES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :pending, -> { where(status: PENDING) }

  sig { returns(T::Boolean) }
  def pending?
    status == PENDING
  end

  sig { returns(T::Boolean) }
  def expired?
    # T.unsafe: `null: false` makes Sorbet read expires_at as always present,
    # but assign_expiry hasn't run yet on an unsaved record.
    deadline = T.unsafe(self).expires_at
    deadline.present? && deadline.past?
  end

  # Whether the join link still leads anywhere. The organization is checked
  # through the association on purpose: Organization is default-scoped to
  # `deleted_at: nil`, so an archived organization reads as nil here and its
  # outstanding invitations stop working.
  sig { returns(T::Boolean) }
  def usable?
    pending? && !expired? && organization.present?
  end

  # The reason this invitation can't be accepted, or nil when it can. Expiry is
  # checked last so a revoked invitation says "revoked" even after it lapses.
  sig { returns(T.nilable(String)) }
  def unusable_reason
    return nil if usable?

    case status
    when ACCEPTED then ALREADY_ACCEPTED_ERROR
    when REVOKED then REVOKED_ERROR
    else EXPIRED_ERROR
    end
  end

  sig { params(user: User).returns(T::Boolean) }
  def addressed_to?(user)
    user.email.to_s.downcase == email
  end

  # Turn the invitation into a membership. The membership row and the status
  # change go in together or not at all — an invitation marked accepted with no
  # membership behind it is unrecoverable, since the token is single-use.
  #
  # Re-accepting as someone who already joined (an admin invited them twice, or
  # they were added directly) closes the invitation out against the membership
  # they already have rather than failing on the uniqueness validation.
  sig { params(user: User).returns(OrganizationMembership) }
  def accept!(user)
    # Callers reach this only through #usable?, which has already established
    # the organization is there.
    org = T.must(organization)

    ApplicationRecord.transaction do
      membership = org.membership_for(user) ||
                   org.organization_memberships.create!(user: user, role: role)

      update!(status: ACCEPTED, accepted_at: Time.current)

      membership
    end
  end

  sig { void }
  def revoke!
    update!(status: REVOKED)
  end

  private

  # Stored downcased so the partial unique index and the `invitation.email ==
  # current_user.email` check in Mutations::AcceptOrganizationInvitation both
  # compare like with like.
  sig { void }
  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  # T.unsafe on both: the columns are `null: false`, so Sorbet reads them as
  # always present and calls the `||=` dead — but that is exactly what these
  # callbacks are here to make true. Same shape as Card#generate_external_id.
  sig { void }
  def assign_token
    T.unsafe(self).token ||= SecureRandom.urlsafe_base64(TOKEN_BYTES)
  end

  sig { void }
  def assign_expiry
    T.unsafe(self).expires_at ||= EXPIRES_IN.from_now
  end
end
