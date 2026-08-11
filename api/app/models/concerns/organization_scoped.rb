# typed: false
# frozen_string_literal: true

# Ownership and access for records that can live either in a user's personal
# space or inside an organization. Included by Card and Invitation, which share
# no other code but need exactly the same rule.
#
# `organization_id` NULL means personal — the pre-organizations behaviour, and
# what every row created before #122 is. It is a real value, not a missing one.
#
# The access rule, from the organizations epic (#115):
#
#   * any member of the owning organization may **view**
#   * the owner, or an **admin** of the owning organization, may **edit**
#     (which covers delivering, locking, and deleting)
#
# Both predicates deliberately say nothing about anonymous access. Public
# sharing by `external_id`/`slug` is governed by the unguessable id and
# Card#require_login_to_contribute, and is unaffected by organization
# ownership — see GraphqlController::PUBLIC_OPERATIONS.
#
# Typed `false` like the other model concerns: everything here calls back into
# ActiveRecord methods (`belongs_to`, `scope`, `where`, `user_id`) that only
# exist on the including class.
module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :organization, optional: true

    # The records visible in one context. Personal is `user`'s own rows with no
    # organization — without the `organization_id: nil` half, switching to
    # Personal would still show everything the user created inside an org.
    scope :in_context, ->(user, organization) {
      organization ? where(organization: organization) : where(user: user, organization_id: nil)
    }
  end

  # Reads through the `organization` association rather than the raw id on
  # purpose: Organization is default-scoped to `deleted_at: nil`, so an archived
  # organization resolves to nil here and its records fall back to owner-only.
  # An archived org must not keep granting access to its former members.
  def owning_organization
    organization
  end

  def viewable_by?(user)
    return false if user.nil?
    return true if user_id == user.id

    owning_organization&.membership_for(user).present?
  end

  def editable_by?(user)
    return false if user.nil?
    return true if user_id == user.id

    owning_organization&.membership_for(user)&.admin? || false
  end
end
