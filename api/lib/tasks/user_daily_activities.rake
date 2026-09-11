# typed: false

namespace :user_daily_activities do
  desc "Backfill user_daily_activities from existing creation timestamps (#182)"
  task backfill: :environment do
    # "Made something" is a narrower, different metric than "made a request" —
    # the real definition, tracked live from UserDailyActivity::BACKFILL_CUTOFF_ON
    # onward (see GraphqlController#record_user_activity). This is only meant to
    # give the charts in cardjoy-admin#5 something to show before that date, and
    # is exposed as such on Types::AdminMetricsType.
    #
    # `.unscoped` on the four soft-deletable products: a card the user later
    # archived still means they were active the day they created it. Rsvp has
    # no default scope, but is the one source a guest can act on with no
    # account at all, so its rows are filtered to the ones that have one.
    sources = {
      Card => Card.unscoped,
      Invitation => Invitation.unscoped,
      HolidayCard => HolidayCard.unscoped,
      Message => Message.unscoped,
      Rsvp => Rsvp.where.not(user_id: nil)
    }

    total_inserted = 0

    sources.each do |model, scope|
      rows = scope
        .select("DISTINCT user_id, DATE(created_at) AS activity_date")
        .map { |row| { user_id: row.user_id, activity_date: row.activity_date } }

      inserted = 0
      # Batched so a table with a lot of history doesn't build one enormous
      # INSERT; `unique_by` is what makes this idempotent — re-running the task
      # (or a row a later source has already covered) is a no-op, never a
      # duplicate or an error.
      rows.each_slice(1000) do |batch|
        result = UserDailyActivity.insert_all(batch, unique_by: [ :user_id, :activity_date ])
        inserted += result.count
      end

      total_inserted += inserted
      puts "#{model.name}: #{rows.size} distinct user/day pairs scanned, #{inserted} new rows"
    end

    puts "Backfill complete: #{total_inserted} rows inserted."
    puts "Live tracking starts #{UserDailyActivity::BACKFILL_CUTOFF_ON} — everything before that is this backfill."
  end
end
