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

  # How far ahead the proactive reminder engine looks (issue #28) when the user
  # hasn't chosen otherwise: an occasion gets a reminder once its next occurrence
  # is within this many days. Also the column default.
  REMINDER_LEAD_DAYS = 7

  # The lead times a user can pick from (issue #100). A closed set rather than a
  # free-form number keeps the picker simple and the reminder windows sane;
  # `nil` is the off switch.
  REMINDER_LEAD_DAY_OPTIONS = [ 1, 3, 7, 14, 30 ].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :occurs_on, presence: true
  validates :recurring, inclusion: { in: [ true, false ] }
  validates :reminder_lead_days, inclusion: { in: REMINDER_LEAD_DAY_OPTIONS }, allow_nil: true

  # Whether this occasion sends a reminder at all — the user can turn it off.
  sig { returns(T::Boolean) }
  def reminders_enabled?
    !reminder_lead_days.nil?
  end

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

  # Occasions across all users whose next occurrence falls within their own
  # reminder lead window and that have not yet been reminded for that occurrence.
  # This is the daily reminder engine's query (issue #28). Each occasion carries
  # its own lead time (issue #100), and occasions with reminders switched off are
  # excluded outright. Recurring occurrences differ from the stored `occurs_on`
  # and the window varies per row, so the filter finishes in Ruby.
  sig { returns(T::Array[Occasion]) }
  def self.due_for_reminder
    today = Date.current
    where.not(reminder_lead_days: nil).includes(contact: :user).select do |occasion|
      occurrence = occasion.next_occurrence(from: today)
      window_end = today + T.must(occasion.reminder_lead_days).days
      occurrence.between?(today, window_end) && !occasion.reminded_for?(occurrence)
    end.sort_by { |occasion| occasion.next_occurrence(from: today) }
  end

  # Whether a reminder has already gone out for the given occurrence. Reminders
  # only ever send inside the window [occurrence - lead_days, occurrence], so any
  # prior reminder timestamp on or after that window's start belongs to this
  # occurrence — which makes the check correct across recurring years without a
  # separate per-occurrence record. Defaults to this occasion's own lead time, so
  # shortening the lead after a reminder has gone out can produce one more
  # reminder at the new, closer date — which is what the user just asked for.
  sig { params(occurrence: Date, lead_days: T.nilable(Integer)).returns(T::Boolean) }
  def reminded_for?(occurrence, lead_days: nil)
    reminded_at = last_reminded_at
    return false if reminded_at.nil?
    lead = lead_days || reminder_lead_days || REMINDER_LEAD_DAYS
    reminded_at.to_date >= occurrence - lead.days
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
