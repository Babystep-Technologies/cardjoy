# typed: true

module Queries
  # The 1-on-1 product's north-star metrics (#30): creation completion rate,
  # occasions saved per user, reminder-to-card conversion, and 1-on-1 -> group
  # card cross-over. See Types::AdminOneOnOneMetricsType for each metric's
  # exact definition.
  #
  # Cached the same way Queries::AdminMetrics is — keyed by window and today's
  # date, a few minutes' TTL — since every metric here is at least one grouped
  # aggregate query.
  class AdminOneOnOneMetrics < BaseQuery
    type Types::AdminOneOnOneMetricsType, null: false

    argument :window, Types::MetricsWindowType, required: true

    CACHE_TTL = 5.minutes

    def resolve(window:)
      admin = context[:current_admin]
      raise GraphQL::ExecutionError, NOT_AUTHORIZED_ERROR unless admin

      Rails.cache.fetch("admin_one_on_one_metrics/#{window}/#{Date.current}", expires_in: CACHE_TTL) do
        compute(window)
      end
    end

    private

    def compute(window)
      range = MetricsWindowRange.new(window)

      flow_starts = ::OneOnOneFlowStart.where(created_at: range.sql_range).count
      cards_created = ::Card.where(kind: "one_on_one", created_at: range.sql_range).count

      occasions_saved = ::Occasion.where(created_at: range.sql_range).count
      users_with_occasions = ::Occasion.where(created_at: range.sql_range).joins(:contact).distinct.count("contacts.user_id")

      reminders_sent = ::Occasion.where(last_reminded_at: range.sql_range).count
      cards_from_reminder = ::Card.where(kind: "one_on_one", created_at: range.sql_range)
        .where.not(source_occasion_id: nil).count

      senders, crossed_over = cross_over_counts(range)

      {
        window: window,
        start_date: range.start_date,
        end_date: range.end_date,
        flow_starts: flow_starts,
        one_on_one_cards_created: cards_created,
        creation_completion_rate: rate(cards_created, flow_starts),
        occasions_saved: occasions_saved,
        users_with_occasions: users_with_occasions,
        occasions_saved_per_user: rate(occasions_saved, users_with_occasions),
        reminders_sent: reminders_sent,
        cards_from_reminder: cards_from_reminder,
        reminder_conversion_rate: rate(cards_from_reminder, reminders_sent),
        one_on_one_senders: senders,
        crossed_over_to_group_card: crossed_over,
        cross_over_rate: rate(crossed_over, senders)
      }
    rescue ArgumentError => e
      raise GraphQL::ExecutionError, e.message
    end

    # Two grouped aggregates rather than one query per user: every user's
    # first-ever 1-on-1 card date, and (for just the cohort that falls in this
    # window) every user's first-ever group card date. A user has crossed over
    # if their first group card is later than their first 1-on-1 card.
    def cross_over_counts(range)
      first_one_on_one = ::Card.where(kind: "one_on_one").group(:user_id).minimum(:created_at)
      cohort = first_one_on_one.select { |_user_id, at| range.sql_range.cover?(at) }.keys
      return [ 0, 0 ] if cohort.empty?

      first_group = ::Card.where(kind: "group", user_id: cohort).group(:user_id).minimum(:created_at)
      crossed_over = cohort.count { |user_id| first_group[user_id] && first_group[user_id] > first_one_on_one[user_id] }

      [ cohort.size, crossed_over ]
    end

    def rate(numerator, denominator)
      return 0.0 if denominator.zero?

      numerator.to_f / denominator
    end
  end
end
