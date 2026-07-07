Rails.application.configure do
  # Run the GoodJob executor inside the Puma web process — no separate worker
  # service and no Redis. The Cloud Run API instance is always warm
  # (min_instances=1) with CPU always allocated, so jobs process reliably.
  config.good_job.execution_mode = :async
  config.good_job.max_threads = 5
  config.good_job.poll_interval = 30
  config.good_job.shutdown_timeout = 25
end
