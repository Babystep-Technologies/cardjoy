# typed: true

# Joins a User to an Organization with a role. An organization must always keep
# at least one admin — otherwise nobody can invite members, allocate credits, or
# edit branding, and the organization is permanently unmanageable.
class OrganizationMembership < ApplicationRecord
  extend T::Sig

  ADMIN = "admin"
  MEMBER = "member"
  ROLES = [ ADMIN, MEMBER ].freeze

  LAST_ADMIN_ERROR = "An organization must have at least one admin"

  belongs_to :organization
  belongs_to :user

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id, message: "is already a member of this organization" }

  # Demotion is a validation so callers get a normal errors array; removal is a
  # before_destroy because there is nothing to validate against.
  validate :organization_retains_an_admin, on: :update, if: :demoting_an_admin?
  before_destroy :ensure_organization_retains_an_admin
  after_destroy :clear_active_organization

  sig { returns(T::Boolean) }
  def admin?
    role == ADMIN
  end

  private

  sig { returns(T::Boolean) }
  def demoting_an_admin?
    role_changed? && role_was == ADMIN
  end

  # True when this is the only admin left. Reads through `organization_id`
  # rather than the association: Organization's default scope makes
  # `organization` nil once the org is archived.
  sig { returns(T::Boolean) }
  def last_admin?
    return false unless persisted?

    !self.class
         .where(organization_id: organization_id, role: ADMIN)
         .where.not(id: id)
         .exists?
  end

  sig { void }
  def organization_retains_an_admin
    errors.add(:base, LAST_ADMIN_ERROR) if last_admin?
  end

  # A removed member must not be left sitting in a context they can no longer
  # read, so drop them back to Personal. Written with update_all so it neither
  # re-runs User's validations (which would now reject the stale value) nor
  # depends on the user being loaded in memory.
  sig { void }
  def clear_active_organization
    User.where(id: user_id, active_organization_id: organization_id)
        .update_all(active_organization_id: nil)
  end

  sig { void }
  def ensure_organization_retains_an_admin
    # Tearing down the whole organization takes its memberships with it; the
    # guard only protects a still-live organization.
    return if destroyed_by_association
    return unless admin?
    return unless last_admin?

    errors.add(:base, LAST_ADMIN_ERROR)
    throw :abort
  end
end
