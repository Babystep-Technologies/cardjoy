# typed: true

# A customer's support conversation (#172): a subject, a category, and a
# thread of SupportTicketMessage rows. Replaces the old fire-and-forget email
# in Mutations::CreateSupportRequest, which stays working but deprecated until
# #175 ships the replacement UI.
class SupportTicket < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_admin, class_name: "Admin", optional: true
  has_many :messages, -> { order(created_at: :asc) }, class_name: "SupportTicketMessage", dependent: :destroy

  # The four options already offered in the web support dialog
  # (web/src/pages/Profile.tsx) — seeded here so the model is the source of
  # truth going forward.
  CATEGORIES = [ "Account question", "Product features", "Credits & promos", "Others" ].freeze

  # Needs a staff reply. Every ticket starts here.
  OPEN = "open"
  # Waiting on the customer. A customer reply moves this back to OPEN.
  PENDING = "pending"
  RESOLVED = "resolved"
  CLOSED = "closed"

  STATUSES = [ OPEN, PENDING, RESOLVED, CLOSED ].freeze

  validates :external_id, presence: true, uniqueness: true, format: { with: /\A[A-Z]{7}\z/ }
  validates :subject, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  before_validation :generate_external_id, on: :create

  default_scope { where(deleted_at: nil) }

  def delete!; update!(deleted_at: Time.current); end
  def deleted?; deleted_at.present?; end

  def pending?; status == PENDING; end

  def open!; update!(status: OPEN); end
  def mark_pending!; update!(status: PENDING); end
  def resolve!; update!(status: RESOLVED); end
  def close!; update!(status: CLOSED); end

  # Appends a customer message and moves `pending` back to `open` — a customer
  # replying is exactly the event that means staff owes another answer.
  # Atomic so a ticket can never show a `lastCustomerReplyAt` newer than its
  # own last message, or vice versa.
  def record_customer_reply!(user:, body:)
    transaction do
      messages.create!(author_kind: SupportTicketMessage::CUSTOMER, author_id: user.id, body:)
      update!(last_customer_reply_at: Time.current, status: (pending? ? OPEN : status))
    end
  end

  private

  def generate_external_id
    # Only capital letters A-Z, mirroring Card#generate_external_id — short
    # enough to paste into an email subject.
    # T.unsafe: Sorbet doesn't understand this is called in before_validation
    # where external_id may be nil.
    T.unsafe(self).external_id ||= T.cast(Array("A".."Z").sample(7), T::Array[String]).join
  end
end
