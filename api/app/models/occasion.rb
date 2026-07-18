# typed: true

# A dated event belonging to a Contact (birthday, work anniversary, graduation…).
# `recurring` marks the annual occasions; for those the meaningful date is the
# next anniversary of `occurs_on`, computed by #next_occurrence. This is the
# retention engine's core datum — CardJoy reminds users as occasions approach.
class Occasion < ApplicationRecord
  extend T::Sig

  belongs_to :contact
  has_one :user, through: :contact

  # Reuse the card occasion vocabulary so the two stay in sync (issue #26).
  KINDS = ::Card::OCCASIONS

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :occurs_on, presence: true
  validates :recurring, inclusion: { in: [ true, false ] }

  # The next date this occasion falls on, on or after `from`. For non-recurring
  # occasions that is simply `occurs_on` (which may be in the past). For
  # recurring ones it is the next anniversary of `occurs_on`.
  sig { params(from: Date).returns(Date) }
  def next_occurrence(from: Date.current)
    return occurs_on unless recurring

    this_year = safe_date(from.year, occurs_on.month, occurs_on.day)
    this_year >= from ? this_year : safe_date(from.year + 1, occurs_on.month, occurs_on.day)
  end

  # Occasions for `user` whose next occurrence falls within the next
  # `within_days` days (inclusive of today), soonest first.
  sig { params(user: User, within_days: Integer).returns(T::Array[Occasion]) }
  def self.upcoming(user:, within_days: 30)
    today = Date.current
    window_end = today + within_days.days
    where(contact: user.contacts)
      .select { |occasion| occasion.next_occurrence.between?(today, window_end) }
      .sort_by(&:next_occurrence)
  end

  private

  # Feb 29 has no counterpart in non-leap years; clamp to the last valid day of
  # the month so an annual occasion still resolves to a real date.
  sig { params(year: Integer, month: Integer, day: Integer).returns(Date) }
  def safe_date(year, month, day)
    Date.new(year, month, day)
  rescue Date::Error
    Date.new(year, month, -1)
  end
end
