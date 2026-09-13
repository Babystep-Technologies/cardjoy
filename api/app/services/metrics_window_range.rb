# typed: true

# Resolves a Types::MetricsWindowType value to the calendar range it covers
# (#183). Top-level, not nested under a module named after Queries::AdminMetrics
# — that name is already a constant one lexical scope up from anywhere inside
# that resolver, which would shadow a same-named module and break the bare
# `AdminMetrics::WindowRange` reference this class's obvious name would invite.
#
# `dau_start_date` is separate from `start_date`: the 7-day rolling average
# needs six days of lookback before the window begins, or its first in-window
# point would be an average of fewer than 7 days rather than a real one. Every
# other series only ever reads `start_date..end_date`.
#
# Reporting timezone (#223): every day boundary this class and every
# `GROUP BY DATE(created_at)` query (Queries::AdminMetrics, Queries::DailyMetrics)
# uses is a **UTC calendar day**. `config.time_zone` is unset in
# `config/application.rb`, so `Time.zone` is Rails's UTC default; `created_at`
# columns are `timestamp without time zone` holding UTC instants
# (ActiveRecord's default), and Postgres's `DATE()` takes the date portion of
# that raw value with no zone conversion — there is no separate "app timezone"
# to drift from. `Date.current` (used for `end_date` and window starts) reads
# through `Time.zone`, so it also lands on the UTC calendar day. A future
# per-admin or per-organization display timezone would need to shift day
# boundaries at read time; it must not change what these queries group by.
class MetricsWindowRange
  ROLLING_AVERAGE_LOOKBACK_DAYS = 6

  WINDOWS = %w[THIRTY_DAYS NINETY_DAYS YEAR_TO_DATE ALL_TIME].freeze

  attr_reader :window, :start_date, :end_date

  def initialize(window)
    raise ArgumentError, "Invalid window: #{window}" unless WINDOWS.include?(window)

    @window = window
    @end_date = Date.current
    @start_date = compute_start_date
  end

  def dau_start_date
    start_date - ROLLING_AVERAGE_LOOKBACK_DAYS
  end

  # `created_at`/`activity_date` columns are compared against this; datetime
  # columns need the day widened to a real range, or a row created at 11pm on
  # the last day of the window is excluded.
  def sql_range
    start_date.beginning_of_day..end_date.end_of_day
  end

  private

  def compute_start_date
    case window
    when "THIRTY_DAYS" then end_date - 29.days
    when "NINETY_DAYS" then end_date - 89.days
    when "YEAR_TO_DATE" then end_date.beginning_of_year
    when "ALL_TIME" then earliest_activity_date
    end
  end

  # The earliest row across everything this dashboard counts, so "all time"
  # means the product's actual history rather than an arbitrary epoch. Falls
  # back to today when there is no data yet (a fresh environment), so the
  # range is never invalid.
  #
  # `.unscoped` on the three soft-deletable products: an archived card is
  # still part of the product's history for the purpose of "when did this
  # start", even though it no longer counts toward creation totals (see
  # Queries::AdminMetrics, which reads the default-scoped counts).
  def earliest_activity_date
    [
      ::User.minimum(:created_at),
      ::Card.unscoped.minimum(:created_at),
      ::Invitation.unscoped.minimum(:created_at),
      ::HolidayCard.unscoped.minimum(:created_at)
    ].compact.min&.to_date || end_date
  end
end
