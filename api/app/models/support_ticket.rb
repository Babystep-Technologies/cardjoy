# typed: true

# A customer's support conversation (#172): a subject, a category, and a
# thread of SupportTicketMessage rows. Replaces the old fire-and-forget email
# in Mutations::CreateSupportRequest, which stays working but deprecated until
# #175 ships the replacement UI.
class SupportTicket < ApplicationRecord
  belongs_to :user
  belongs_to :assigned_admin, class_name: "Admin", optional: true
  belongs_to :status_updated_by_admin, class_name: "Admin", optional: true
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

  # Bytes of randomness in reply_token, matching OrganizationInvitation::TOKEN_BYTES.
  REPLY_TOKEN_BYTES = 32

  validates :external_id, presence: true, uniqueness: true, format: { with: /\A[A-Z]{7}\z/ }
  validates :subject, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reply_token, presence: true, uniqueness: true

  before_validation :generate_external_id, on: :create
  before_validation :generate_reply_token, on: :create

  default_scope { where(deleted_at: nil) }

  # A deleted ticket also stops accepting mailed-in replies — its reply_token
  # is revoked in the same stroke, so SupportTicketMailbox bounces mail that
  # arrives for it instead of reviving a thread nobody can see anymore.
  def delete!; update!(deleted_at: Time.current, reply_token_revoked_at: Time.current); end
  def deleted?; deleted_at.present?; end

  def revoke_reply_token!; update!(reply_token_revoked_at: Time.current); end
  def reply_token_revoked?; reply_token_revoked_at.present?; end

  # The address SupportTicketMailer sets as `reply_to` on every admin reply
  # (#174). Routes back to this exact ticket via ApplicationMailbox's
  # `support+` rule and SupportTicketMailbox.
  def reply_to_address
    "support+#{reply_token}@#{AppConfig.support_inbound_email_domain}"
  end

  # SupportTicketMailbox's lookup for an inbound reply's token. Unknown or
  # revoked tokens (including a deleted ticket's, which revokes on delete!)
  # both return nil, so the mailbox bounces rather than creating an orphan
  # message.
  def self.active_for_reply_token(token)
    return nil if token.blank?

    find_by(reply_token: token, reply_token_revoked_at: nil)
  end

  def pending?; status == PENDING; end

  def open!; update!(status: OPEN); end
  def mark_pending!; update!(status: PENDING); end
  def resolve!; update!(status: RESOLVED); end
  def close!; update!(status: CLOSED); end

  # Appends a customer message and moves `pending` back to `open` — a customer
  # replying is exactly the event that means staff owes another answer.
  # Atomic so a ticket can never show a `lastCustomerReplyAt` newer than its
  # own last message, or vice versa.
  # `inbound_email_id` is set only when the reply arrived by mail
  # (SupportTicketMailbox); the customer-facing ReplyToSupportTicket mutation
  # leaves it nil, same as every message created before #174.
  def record_customer_reply!(user:, body:, inbound_email_id: nil)
    transaction do
      messages.create!(author_kind: SupportTicketMessage::CUSTOMER, author_id: user.id, body:, inbound_email_id:)
      update!(last_customer_reply_at: Time.current, status: (pending? ? OPEN : status))
    end
  end

  # Appends a staff reply and moves the ticket to `new_status` — `pending` by
  # default, since a reply is normally the ticket going back to waiting on the
  # customer. Atomic for the same reason record_customer_reply! is: a ticket
  # can never show a `lastAdminReplyAt` newer than its own last message.
  #
  # `new_status` is trusted to already be a valid status — the mutation checks
  # that before calling in, the same way Mutations::CreateSupportTicket checks
  # `category` before building the ticket.
  #
  # Does not send the customer email itself — the caller enqueues
  # SupportTicketMailer#admin_reply once this returns, so a mailer failure
  # can never roll back a reply that already happened.
  def receive_admin_reply!(admin:, body:, new_status: nil)
    message = T.let(nil, T.nilable(SupportTicketMessage))
    transaction do
      message = messages.create!(author_kind: SupportTicketMessage::ADMIN, author_id: admin.id, body:)
      update!(last_admin_reply_at: Time.current, status: new_status.presence || PENDING)
    end
    message
  end

  def update_status_by_admin!(admin:, status:)
    update!(status:, status_updated_by_admin: admin)
  end

  def assign_to!(admin:)
    update!(assigned_admin: admin)
  end

  private

  def generate_external_id
    # Only capital letters A-Z, mirroring Card#generate_external_id — short
    # enough to paste into an email subject.
    # T.unsafe: Sorbet doesn't understand this is called in before_validation
    # where external_id may be nil.
    T.unsafe(self).external_id ||= T.cast(Array("A".."Z").sample(7), T::Array[String]).join
  end

  # T.unsafe: same escape hatch as generate_external_id — this callback is
  # what makes `||=` true on a new record, so Sorbet can't be trusted to see
  # reply_token as possibly nil here.
  def generate_reply_token
    T.unsafe(self).reply_token ||= SecureRandom.urlsafe_base64(REPLY_TOKEN_BYTES)
  end
end
