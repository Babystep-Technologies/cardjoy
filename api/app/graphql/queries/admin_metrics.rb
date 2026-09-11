# typed: true

module Queries
  # The metrics dashboard's one query (#183): totals and a daily series for a
  # selected window, replacing the old fixed 1/7/30/90/180-day fan-out in
  # Queries::BusinessMetrics — 24 independent COUNT(*)s, none grouped, none
  # cached — with ~8 grouped queries total, cached for a few minutes.
  # BusinessMetrics and DailyMetrics are left unchanged; deprecating them is a
  # follow-up once cardjoy-admin#5 has migrated off them.
  #
  # Cached keyed by window and today's date: short enough that a correction (an
  # admin fixing a chargeback, say) shows up within minutes, and the date in
  # the key is what expires yesterday's numbers instead of an all-time or YTD
  # total sitting stale for a whole TTL cycle at the day boundary.
  class AdminMetrics < BaseQuery
    type Types::AdminMetricsType, null: false

    argument :window, Types::MetricsWindowType, required: true

    CACHE_TTL = 5.minutes

    def resolve(window:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      Rails.cache.fetch("admin_metrics/#{window}/#{Date.current}", expires_in: CACHE_TTL) do
        compute(window)
      end
    end

    private

    def compute(window)
      range = MetricsWindowRange.new(window)

      cards = day_kind_counts(::Card.where(created_at: range.sql_range))
      invitations = day_counts(::Invitation.where(created_at: range.sql_range))
      holiday_cards = day_counts(::HolidayCard.where(created_at: range.sql_range))
      users = day_counts(::User.where(created_at: range.sql_range))
      rsvps = day_counts(::Rsvp.where(created_at: range.sql_range))
      rsvps_by_status = day_status_counts(::Rsvp.where(created_at: range.sql_range))
      dau = dau_series(range)

      days = (range.start_date..range.end_date).to_a
      daily_series = days.map do |date|
        {
          date: date,
          dau: dau[:counts][date] || 0,
          dau_rolling_7d: dau[:rolling][date] || 0.0,
          new_users: users[date] || 0,
          group_cards: cards[[ date, "group" ]] || 0,
          one_on_one_cards: cards[[ date, "one_on_one" ]] || 0,
          invitations: invitations[date] || 0,
          holiday_cards: holiday_cards[date] || 0,
          rsvps: rsvps[date] || 0
        }
      end

      going = rsvps_by_status.select { |(_date, status), _count| status == "going" }.values.sum
      maybe = rsvps_by_status.select { |(_date, status), _count| status == "maybe" }.values.sum
      not_going = rsvps_by_status.select { |(_date, status), _count| status == "not-going" }.values.sum

      {
        window: window,
        start_date: range.start_date,
        end_date: range.end_date,
        new_users: users.values.sum,
        group_cards: daily_series.sum { |d| d[:group_cards] },
        one_on_one_cards: daily_series.sum { |d| d[:one_on_one_cards] },
        invitations: invitations.values.sum,
        holiday_cards: holiday_cards.values.sum,
        rsvps_going: going,
        rsvps_maybe: maybe,
        rsvps_not_going: not_going,
        total_attendees: going + ::Rsvp.going.where(created_at: range.sql_range).sum(:additional_guests_count),
        current_dau_rolling_7d: daily_series.last&.fetch(:dau_rolling_7d) || 0.0,
        dau_backfill_boundary: ::UserDailyActivity::BACKFILL_CUTOFF_ON,
        daily_series: daily_series
      }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end

    # Distinct users active per day (the table's unique index means a plain
    # COUNT already is a distinct-user count — no row can duplicate a
    # (user_id, activity_date) pair), plus the trailing 7-day average of that
    # per day in the window. Queried from `range.dau_start_date` — six days
    # before the window itself — so the window's first day still has 7 real
    # days of lookback rather than winding up from zero.
    def dau_series(range)
      counts = normalize_day_keys(
        ::UserDailyActivity.where(activity_date: range.dau_start_date..range.end_date)
          .group(:activity_date)
          .count
      )

      rolling = {}
      (range.start_date..range.end_date).each do |date|
        window_days = (date - 6)..date
        values = window_days.map { |d| counts[d] || 0 }
        rolling[date] = values.sum.to_f / values.size
      end

      { counts: counts, rolling: rolling }
    end

    def day_counts(scope)
      normalize_day_keys(scope.group("DATE(created_at)").count)
    end

    def day_kind_counts(scope)
      scope.group("DATE(created_at)", :kind).count.transform_keys { |(date, kind)| [ normalize_date(date), kind ] }
    end

    def day_status_counts(scope)
      scope.group("DATE(created_at)", :status).count.transform_keys { |(date, status)| [ normalize_date(date), status ] }
    end

    def normalize_day_keys(hash)
      hash.transform_keys { |date| normalize_date(date) }
    end

    # `GROUP BY DATE(created_at)` comes back as a String key on some adapters
    # and a Date on others; every lookup in this resolver keys on a real Date,
    # so this is the one place that ambiguity gets resolved.
    def normalize_date(value)
      value.is_a?(String) ? Date.parse(value) : value.to_date
    end
  end
end
