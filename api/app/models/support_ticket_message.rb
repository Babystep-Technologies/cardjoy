# typed: true

# One message in a SupportTicket's thread (#172). `author_id` is deliberately
# not a `belongs_to :author` — User and Admin are separate models with
# separate id spaces, so the same integer means different things depending on
# `author_kind`. Resolve it with `User.find_by(id:)` or `Admin.find_by(id:)`
# rather than adding a polymorphic association here, since polymorphic
# `belongs_to` would need `author_type` to hold a Rails class name, and
# "system" messages have no author at all.
class SupportTicketMessage < ApplicationRecord
  belongs_to :support_ticket

  CUSTOMER = "customer"
  ADMIN = "admin"
  SYSTEM = "system"

  AUTHOR_KINDS = [ CUSTOMER, ADMIN, SYSTEM ].freeze

  validates :author_kind, presence: true, inclusion: { in: AUTHOR_KINDS }
  validates :author_id, presence: true, unless: :system_author?
  validates :body, presence: true

  default_scope { where(deleted_at: nil) }

  def delete!; update!(deleted_at: Time.current); end
  def deleted?; deleted_at.present?; end

  private

  def system_author?
    author_kind == SYSTEM
  end
end
