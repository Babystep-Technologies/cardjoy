# typed: true

# A named, reusable group of a user's contacts — "the 2026 card list",
# "Marshall's side of the family". The point of a list is that it survives from
# one December to the next: the user curates it once and addresses a holiday
# card to it every year, rather than ticking forty checkboxes each time.
#
# Always user-scoped. A list and every contact on it belong to the same user;
# see ContactListMembership for where that is enforced.
class ContactList < ApplicationRecord
  NAME_MAX_LENGTH = 100

  DUPLICATE_NAME_MESSAGE = "is already used by another list"

  # One message for "no such list" and "not yours", so a caller can't use the
  # difference to probe which list ids exist. Shared by the four list mutations.
  NOT_FOUND_ERROR = "Contact list not found or not owned by user"

  belongs_to :user
  has_many :contact_list_memberships, dependent: :destroy
  # Destroying a list takes its memberships with it and leaves the contacts
  # themselves alone — the list is a grouping, not an owner.
  has_many :contacts, through: :contact_list_memberships

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  # Deliberately stricter than the unique index on [user_id, name], which is
  # exact-match: "Family" and "family" are the same list as far as a human is
  # concerned. The index remains the backstop for a concurrent double-create.
  validates :name,
            uniqueness: { scope: :user_id, case_sensitive: false, message: DUPLICATE_NAME_MESSAGE },
            allow_blank: true

  # The contacts on this list a carrier could actually deliver to. Computed in
  # SQL rather than by filtering `contacts` in Ruby so the counts below stay a
  # single query — the UI wants "38 of 42 contacts have an address" without
  # loading forty rows to find out.
  def mailable_contacts
    contacts.mailable
  end

  def contacts_count
    contacts.count
  end

  def mailable_contacts_count
    mailable_contacts.count
  end

  private

  # Surrounding whitespace would otherwise make " Family" a second list called
  # "Family", which is exactly what the uniqueness rule is there to prevent.
  def normalize_name
    self.name = name.strip if name.is_a?(String)
  end
end
