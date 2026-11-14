Rails.application.configure do
  # Run the GoodJob executor inside the Puma web process — no separate worker
  # service and no Redis. The API process stays warm, so jobs process reliably.
  config.good_job.execution_mode = :async
  config.good_job.max_threads = 5
  config.good_job.poll_interval = 30
  config.good_job.shutdown_timeout = 25

  # Recurring jobs. GoodJob dedupes cron enqueues across processes with an
  # advisory lock, so this is safe even though the executor runs in every Puma
  # worker. The reminder engine (issue #28) runs once a day at 14:00 UTC —
  # mid-morning in the Americas.
  config.good_job.enable_cron = true
  config.good_job.cron = {
    occasion_reminders: {
      cron: "0 14 * * *",
      class: "OccasionReminderJob",
      description: "Email users a reminder ~a week before each upcoming occasion-book occasion"
    },
    registry_event_reminders: {
      cron: "30 14 * * *",
      class: "RegistryEventReminderJob",
      description: "Nudge registry owners to share their registry ahead of the event"
    },
    stale_wish_list_claims: {
      cron: "0 15 * * *",
      class: "StaleWishListClaimsJob",
      description: "Remind guests about unbought registry claims, and release the ones nobody acted on"
    },
    refresh_wish_list_prices: {
      cron: "0 16 * * *",
      class: "RefreshWishListPricesJob",
      description: "Re-read registry item prices from their links, a bounded batch a day"
    },
    scrub_guest_emails: {
      cron: "30 15 * * *",
      class: "ScrubGuestEmailsJob",
      description: "Erase guests' email addresses a week after a registry's event"
    }
  }
end
