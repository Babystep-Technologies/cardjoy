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

  # How far ahead the proactive reminder engine looks (issue #28): an occasion
  # gets a reminder once its next occurrence is within this many days.
  REMINDER_LEAD_DAYS = 7

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

  # Occasions across all users whose next occurrence falls within the reminder
  # lead window and that have not yet been reminded for that occurrence. This is
  # the daily reminder engine's query (issue #28). Recurring occurrences differ
  # from the stored `occurs_on`, so the window can't be a pure SQL range; we
  # narrow on `occurs_on` where cheap and finish the filter in Ruby.
  sig { params(lead_days: Integer).returns(T::Array[Occasion]) }
  def self.due_for_reminder(lead_days: REMINDER_LEAD_DAYS)
    today = Date.current
    window_end = today + lead_days.days
    includes(contact: :user).select do |occasion|
      occurrence = occasion.next_occurrence(from: today)
      occurrence.between?(today, window_end) && !occasion.reminded_for?(occurrence, lead_days: lead_days)
    end.sort_by { |occasion| occasion.next_occurrence(from: today) }
  end

  # Whether a reminder has already gone out for the given occurrence. Reminders
  # only ever send inside the window [occurrence - lead_days, occurrence], so any
  # prior reminder timestamp on or after that window's start belongs to this
  # occurrence — which makes the check correct across recurring years without a
  # separate per-occurrence record.
  sig { params(occurrence: Date, lead_days: Integer).returns(T::Boolean) }
  def reminded_for?(occurrence, lead_days: REMINDER_LEAD_DAYS)
    reminded_at = last_reminded_at
    return false if reminded_at.nil?
    reminded_at.to_date >= occurrence - lead_days.days
  end

  # Mark this occasion as reminded now, so the daily job won't re-select it for
  # the current occurrence.
  sig { void }
  def record_reminder!
    update!(last_reminded_at: Time.current)
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
