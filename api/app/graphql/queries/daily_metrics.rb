# typed: true

module Queries
  class DailyMetrics < BaseQuery
    type [ Types::DailyMetricsType ], null: false

    argument :days, Integer, required: false, default_value: 30

    def resolve(days:)
      end_date = Date.today
      start_date = end_date - days.days

      # Generate array of dates
      date_range = (start_date..end_date).to_a

      # Fetch all data at once grouped by date
      users_by_date = ::User
        .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        .group("DATE(created_at)")
        .count

      cards_by_date = ::Card
        .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        .group("DATE(created_at)")
        .count

      invitations_by_date = ::Invitation
        .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        .group("DATE(created_at)")
        .count

      rsvps_by_date = ::Rsvp
        .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        .group("DATE(created_at)")
        .count

      # Build response with all dates, filling in zeros for missing data
      date_range.map do |date|
        {
          date: date.to_s,
          users: users_by_date[date] || 0,
          cards: cards_by_date[date] || 0,
          invitations: invitations_by_date[date] || 0,
          rsvps: rsvps_by_date[date] || 0
        }
      end
    end
  end
end
