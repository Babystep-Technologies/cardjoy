require_relative "boot"
require_relative "../config/initializers/health_check"
require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Api
  class Application < Rails::Application
    config.middleware.insert_before Warden::Manager, HealthCheck
    config.active_record.query_log_tags_enabled = true
    config.active_storage.resolve_model_to_route = :rails_storage_proxy
    config.active_record.query_log_tags = [
      # Rails query log tags:
      :application, :controller, :action, :job,
      # GraphQL-Ruby query log tags:
      current_graphql_operation: -> { GraphQL::Current.operation_name },
      current_graphql_field: -> { GraphQL::Current.field&.path },
      current_dataloader_source: -> { GraphQL::Current.dataloader_source_class }
    ]
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Single source for the JWT signing secret. Credentials win, so deployed
    # environments keep signing with the key they already use; JWT_SECRET_KEY is
    # the fallback for local development, where the gitignored
    # `config/credentials/development.key` is absent on a fresh clone and
    # credentials decrypt to an empty hash. Set here rather than in an
    # initializer because config/initializers/devise.rb reads it and would
    # otherwise load first. See docs/DEVELOPMENT.md.
    config.x.jwt_secret =
      Rails.application.credentials.dig(:jwt, :secret).presence || ENV["JWT_SECRET_KEY"].presence

    # Postgres-backed background jobs via GoodJob (no Redis). See
    # config/initializers/good_job.rb for the execution mode.
    config.active_job.queue_adapter = :good_job

    # We don't use ActiveStorage image metadata/variants, so skip analysis
    # (avoids the AnalyzeJob enqueued on every upload).
    config.active_storage.analyzers = []

    # Enable cookies and session middleware so OmniAuth can function.
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, key: "cardjoy_session_#{Rails.env}", expire_after: 1.month, httponly: true, secure: Rails.env.production?
    config.middleware.use Rack::Attack
  end
end
