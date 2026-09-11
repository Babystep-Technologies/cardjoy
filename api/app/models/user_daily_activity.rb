# typed: true

# One row per user per day they made an authenticated API request (#182). DAU,
# here, means exactly that — not a signup, not a session, just "made a
# request while signed in" — read as a distinct count of user_id grouped by
# activity_date (see Queries::AdminMetrics).
class UserDailyActivity < ApplicationRecord
  belongs_to :user

  # Everything before this date is backfilled from creation timestamps on
  # cards/invitations/holiday_cards/messages/rsvps (see
  # lib/tasks/user_daily_activities.rake) rather than recorded live — a
  # narrower, different metric ("made something" vs. "showed up"). Exposed on
  # Types::AdminMetricsType so the dashboard can mark that range as
  # approximate instead of presenting it as equivalent to the real thing.
  BACKFILL_CUTOFF_ON = Date.new(2026, 9, 11)

  # Records that `user_id` was active today, if it isn't already recorded. A
  # single `INSERT ... ON CONFLICT DO NOTHING` — no preceding read, so two
  # concurrent requests from the same user can't race each other into two rows
  # or a lock wait; the unique index on (user_id, activity_date) is what makes
  # the second insert a silent no-op instead of an error.
  #
  # Called from GraphqlController#set_current_user_or_admin on every
  # authenticated request. Callers must guard this against raising — activity
  # tracking must never fail or slow down the request it rides on.
  def self.record!(user_id)
    insert_all(
      [ { user_id: user_id, activity_date: Date.current } ],
      unique_by: [ :user_id, :activity_date ]
    )
  end
end
