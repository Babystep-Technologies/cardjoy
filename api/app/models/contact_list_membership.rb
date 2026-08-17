# typed: true

# Joins a ContactList to a Contact. Both sides are user-scoped, and nothing at
# the database level stops a row from pairing one user's list with another
# user's contact — a foreign key only checks that the target row exists, not
# who owns it. So the ownership rule lives here, and this validation is the
# only thing standing between a hand-crafted mutation and someone else's
# mailing addresses. Mutations::AddContactsToList checks ownership up front too;
# this is the backstop that makes any other write path safe as well.
class ContactListMembership < ApplicationRecord
  CROSS_USER_MESSAGE = "must belong to the same user as the list"
  DUPLICATE_MESSAGE = "is already on this list"

  belongs_to :contact_list
  belongs_to :contact

  validates :contact_id, uniqueness: { scope: :contact_list_id, message: DUPLICATE_MESSAGE }
  validate :contact_and_list_share_an_owner

  private

  def contact_and_list_share_an_owner
    # Bound to locals so Sorbet can narrow away the nil each association may be
    # before `belongs_to`'s own presence validation has run.
    owner = contact&.user_id
    list_owner = contact_list&.user_id
    return if owner.nil? || list_owner.nil?
    return if owner == list_owner

    errors.add(:contact, CROSS_USER_MESSAGE)
  end
end
