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
    }
  }
end
