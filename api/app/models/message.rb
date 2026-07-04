# typed: true

class Message < ApplicationRecord
  include HasAttachedImage
  include HasReactions

  belongs_to :card
  belongs_to :user

  default_scope { where(deleted_at: nil) }
  scope :not_flagged, -> { where(flagged_at: nil) }

  def archive!; update!(deleted_at: Time.current); end
  def flag!; update!(flagged_at: Time.current); end
  def unflag!; update!(flagged_at: nil); end

  def deleted?; deleted_at.present?; end
  def flagged?; flagged_at.present?; end
  alias_method :flagged, :flagged?
end
