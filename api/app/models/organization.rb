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
