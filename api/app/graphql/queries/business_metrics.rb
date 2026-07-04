# typed: true

module Queries
  class BusinessMetrics < BaseQuery
    type Types::BusinessMetricsType, null: false

    def resolve
      {
        users_last_1_day: ::User.where("created_at >= ?", 1.day.ago).count,
        users_last_7_days: ::User.where("created_at >= ?", 7.days.ago).count,
        users_last_30_days: ::User.where("created_at >= ?", 30.days.ago).count,
        users_last_90_days: ::User.where("created_at >= ?", 90.days.ago).count,
        users_last_180_days: ::User.where("created_at >= ?", 180.days.ago).count,

        cards_last_1_day: ::Card.where("created_at >= ?", 1.day.ago).count,
        cards_last_7_days: ::Card.where("created_at >= ?", 7.days.ago).count,
        cards_last_30_days: ::Card.where("created_at >= ?", 30.days.ago).count,
        cards_last_90_days: ::Card.where("created_at >= ?", 90.days.ago).count,
        cards_last_180_days: ::Card.where("created_at >= ?", 180.days.ago).count,

        invitations_last_1_day: ::Invitation.where("created_at >= ?", 1.day.ago).count,
        invitations_last_7_days: ::Invitation.where("created_at >= ?", 7.days.ago).count,
        invitations_last_30_days: ::Invitation.where("created_at >= ?", 30.days.ago).count,
        invitations_last_90_days: ::Invitation.where("created_at >= ?", 90.days.ago).count,
        invitations_last_180_days: ::Invitation.where("created_at >= ?", 180.days.ago).count,

        rsvps_last_1_day: ::Rsvp.where("created_at >= ?", 1.day.ago).count,
        rsvps_last_7_days: ::Rsvp.where("created_at >= ?", 7.days.ago).count,
        rsvps_last_30_days: ::Rsvp.where("created_at >= ?", 30.days.ago).count,
        rsvps_last_90_days: ::Rsvp.where("created_at >= ?", 90.days.ago).count,
        rsvps_last_180_days: ::Rsvp.where("created_at >= ?", 180.days.ago).count,

        rsvps_going_last_30_days: ::Rsvp.going.where("created_at >= ?", 30.days.ago).count,
        rsvps_maybe_last_30_days: ::Rsvp.maybe.where("created_at >= ?", 30.days.ago).count,
        rsvps_not_going_last_30_days: ::Rsvp.not_going.where("created_at >= ?", 30.days.ago).count,
        total_attendees_last_30_days: calculate_total_attendees(30.days.ago)
      }
    end

    private

    def calculate_total_attendees(since)
      going_rsvps = ::Rsvp.going.where("rsvps.created_at >= ?", since)
      going_rsvps.count + going_rsvps.sum(:additional_guests_count)
    end
  end
end
