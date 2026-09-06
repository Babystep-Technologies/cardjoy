# typed: true

# One physical piece of mail: this card, to this address, charged this many
# cents (issue #148).
#
# ## Why one row per recipient and not one per send
#
# Forty cards to forty people is forty rows. Each one gets its own PostGrid id,
# its own status, its own tracking number, and can fail on its own — a bad
# apartment number on recipient 12 is PostGrid rejecting one postcard, not the
# batch. Modelling the *send* instead would force every one of those outcomes
# into a single status column and leave the user unable to see which two of
# their forty cards didn't go.
#
# Partial failure is therefore the normal case, not the exceptional one. There
# is no batch to be atomic about: an external print service cannot be enrolled
# in our transaction, and pretending otherwise produces worse failure modes than
# admitting it.
#
# ## Why the recipient is snapshotted
#
# `contact_id` is a live reference, and it is nullable. The user can edit the
# address or delete the contact entirely the day after the card is in the mail,
# and the order must still say where it went — for support, for their own
# history, and because the address printed on a card is a fact rather than a
# lookup. `recipient_snapshot` is that fact; `contact_id` is only a convenience
# link back to whoever it was at the time.
#
# ## Why the price is stored in full
#
# `base_cents`, `zone`, `mailing_class`, and `rate_card_version` are all kept
# alongside `charged_cents` because rates move and orders outlive them. "Why was
# I charged 112¢?" is a support question with a right answer, and the answer is
# only reconstructable if the inputs are still here. None of that is exposed to
# the client — see Types::HolidayCardMailOrderType.
class HolidayCardMailOrder < ApplicationRecord
  extend T::Sig

  belongs_to :holiday_card
  belongs_to :user
  # Both optional for the same reason: an order outlives the things it points
  # at. The contact may be deleted; the debit row is only absent on a row built
  # outside the send flow.
  belongs_to :contact, optional: true
  belongs_to :postage_credit, optional: true

  # Created, charged, nothing sent yet. Every order starts here and the wallet
  # has already been debited by the time it exists — which is what makes
  # `pending` the only status a refund may fire from.
  PENDING = "pending"
  # Accepted by PostGrid. `postgrid_id` is set from here on.
  SUBMITTED = "submitted"
  PRINTING = "printing"
  PROCESSED_FOR_DELIVERY = "processed_for_delivery"
  COMPLETED = "completed"
  # Terminal, and refunded. Reached only from `pending`.
  FAILED = "failed"
  CANCELLED = "cancelled"

  STATUSES = [
    PENDING, SUBMITTED, PRINTING, PROCESSED_FOR_DELIVERY, COMPLETED, FAILED, CANCELLED
  ].freeze

  # PostGrid's vocabulary mapped onto ours, at the boundary. Their strings are
  # never stored: they belong to a third party's release notes, and a rename on
  # their side must not rewrite our history or break a client that switches on
  # status. An unrecognised value maps to nil and the caller keeps whatever it
  # already had — a status we don't understand is not a reason to lose one we do.
  STATUS_FROM_POSTGRID = {
    "ready" => SUBMITTED,
    "printing" => PRINTING,
    "processed_for_delivery" => PROCESSED_FOR_DELIVERY,
    "completed" => COMPLETED,
    "cancelled" => CANCELLED
  }.freeze

  # The recipient fields `recipient_snapshot` carries, in Contact's own column
  # names so reading one back needs no translation.
  SNAPSHOT_FIELDS = %i[name address_line1 address_line2 city region postal_code country_code].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :size, :mailing_class, :zone, :rate_card_version, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: true
  # Zero is a real possibility to guard against, not a theoretical one: a
  # rate-card bug that priced a piece at 0 would sail through a plain presence
  # check and mail for free.
  validates :base_cents, :charged_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :for_card, ->(card) { where(holiday_card: card) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  # The only status with a rule attached, so the only one worth a predicate:
  # it is what both submission and refund are allowed to fire from. Everything
  # past `pending` is descriptive, and callers compare against the constants.
  sig { returns(T::Boolean) }
  def pending?
    status == PENDING
  end

  # What we knew about the recipient at send time. A plain hash of strings, not
  # a serialized Contact: the columns this depends on are the six a carrier
  # needs plus a name, and pinning it to Contact's full shape would make every
  # future column change a migration of already-mailed history.
  sig { params(contact: ::Contact).returns(T::Hash[String, T.untyped]) }
  def self.snapshot_for(contact)
    SNAPSHOT_FIELDS.to_h { |field| [ field.to_s, contact.public_send(field) ] }.compact_blank
  end

  # The recipient's name as printed, from the snapshot rather than the contact —
  # the contact may be gone, and even when it isn't, its name today is not
  # necessarily the name on the card.
  sig { returns(T.nilable(String)) }
  def recipient_name
    recipient_snapshot["name"]
  end

  # Record PostGrid's acceptance. `postgrid_status` is their string; ours is
  # derived through STATUS_FROM_POSTGRID, defaulting to `submitted` because a
  # 2xx from a create means they have it either way.
  sig { params(postgrid_id: String, postgrid_status: T.nilable(String)).returns(T::Boolean) }
  def mark_submitted!(postgrid_id:, postgrid_status: nil)
    update!(
      postgrid_id:,
      status: STATUS_FROM_POSTGRID[postgrid_status.to_s] || SUBMITTED,
      submitted_at: Time.current
    )
    true
  end

  # Terminal failure: mark it, say why, and put the money back.
  #
  # The idempotency guard is the **status transition itself**, expressed as a
  # conditional UPDATE. Two concurrent runs of the submission job both issue
  # `UPDATE … WHERE status = 'pending'`; exactly one affects a row, and only
  # that one goes on to refund. A boolean `refunded` flag would be the obvious
  # alternative and the wrong one — it is a second piece of state that a crash
  # between the two writes can leave disagreeing with the ledger, which is
  # precisely the window this closes.
  #
  # Returns false when the order was not `pending`, so a caller can tell "I
  # refunded it" from "somebody already did".
  sig { params(reason: String).returns(T::Boolean) }
  def fail_and_refund!(reason:)
    self.class.transaction do
      claimed = self.class.where(id:, status: PENDING).update_all(
        status: FAILED, failure_reason: reason, updated_at: Time.current
      )
      next false unless claimed == 1

      reload
      T.must(user).refund_postage!(
        cents: charged_cents,
        reason: "holiday_card_mail_refund",
        event_kind: "postage_refunded",
        event_data: { "holiday_card_mail_order_id" => id, "holiday_card_id" => holiday_card_id }
      )
      true
    end
  end
end
