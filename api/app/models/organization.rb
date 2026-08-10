# typed: true

# A group of users who share credits, cards, and branding. Users belong to an
# organization through OrganizationMembership; the creator is seeded as its
# first admin (see Mutations::CreateOrganization).
#
# Soft-deleted via #archive!, mirroring Card and Style. Note the default scope
# means `membership.organization` is nil once an organization is archived —
# callers that can run against an archived org must handle that.
class Organization < ApplicationRecord
  extend T::Sig

  SLUG_MAX_LENGTH = 60

  # Raised by #allocate_credits! when the pool can't cover the allocation.
  class InsufficientPoolCreditsError < StandardError; end

  # Raised by #allocate_credits! when the recipient doesn't belong here.
  class NotAMemberError < StandardError; end

  belongs_to :created_by, class_name: "User"

  has_many :organization_memberships, dependent: :destroy
  has_many :users, through: :organization_memberships
  has_many :organization_invitations, dependent: :destroy
  has_many :organization_credits, dependent: :destroy
  has_many :admin_memberships,
           -> { where(role: OrganizationMembership::ADMIN) },
           class_name: "OrganizationMembership",
           inverse_of: :organization,
           dependent: nil

  before_validation :assign_slug, on: :create

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  default_scope { where(deleted_at: nil) }

  # Signed sum of the shared credit pool, mirroring User#credit_balance:
  # positive rows are purchases/grants in, negative rows are allocations out.
  sig { returns(Integer) }
  def credit_balance
    organization_credits.sum(:amount).to_i
  end

  # Move `amount` credits out of the shared pool and into a member's personal
  # ledger. This is a transfer, not shared spending: once allocated, the credits
  # are the member's own and are spent through the untouched User#spend_credit!.
  #
  # Must run inside a transaction — the two ledger rows are one transfer, and a
  # failure on either has to roll back both. Locks the organization row for the
  # duration of that transaction, so two admins allocating at once can't
  # overdraw the pool (the same guard User#spend_credit! relies on).
  #
  # `allocated_by` is recorded in both audit trails; it is not authorized here,
  # since that is the mutation's job.
  sig { params(user: User, amount: Integer, allocated_by: User).returns(Credit) }
  def allocate_credits!(user:, amount:, allocated_by:)
    raise ArgumentError, "Amount must be positive" unless amount.positive?
    raise NotAMemberError, "Not a member of this organization" unless users.exists?(user.id)

    lock!
    raise InsufficientPoolCreditsError, "Not enough credits in the pool" if credit_balance < amount

    event_data = {
      organization_id: id,
      user_id: user.id,
      allocated_by_user_id: allocated_by.id,
      amount: amount
    }

    organization_credits.create!(
      amount: -amount,
      reason: "org_allocation",
      events: [ allocation_event(event_data) ]
    )

    user.credits.create!(
      amount: amount,
      reason: "org_allocation",
      events: [ allocation_event(event_data) ]
    )
  end

  sig { void }
  def archive!
    update!(deleted_at: Time.current)
  end

  # The caller's membership, or nil when they don't belong here. Used by the
  # authorization helpers on Mutations::BaseMutation.
  sig { params(user: T.nilable(User)).returns(T.nilable(OrganizationMembership)) }
  def membership_for(user)
    return nil if user.nil?

    organization_memberships.find_by(user_id: user.id)
  end

  private

  # Both halves of a transfer carry the same audit entry. `org_credit_allocated`
  # is the kind OrganizationCredit already ships with (see #120); Credit gains
  # it here so the two sides of the transfer read as one event.
  sig { params(event_data: T::Hash[Symbol, T.untyped]).returns(T::Hash[Symbol, T.untyped]) }
  def allocation_event(event_data)
    {
      event_kind: "org_credit_allocated",
      event_happened_at: Time.now.utc.iso8601(3),
      event_data: event_data
    }
  end

  # Derive a URL-safe slug from the name, disambiguating collisions with a
  # numeric suffix. Checked against `unscoped` so an archived organization's
  # slug can't be handed out twice and then rejected by the unique index.
  sig { void }
  def assign_slug
    return if slug.present?

    base = name.to_s.parameterize.presence || "organization"
    base = base.first(SLUG_MAX_LENGTH)

    candidate = base
    suffix = 2
    while self.class.unscoped.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
