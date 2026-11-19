Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = case Rails.env
    when "staging"
                        [
                          "https://admin-staging.felicito.app",
                          "https://staging.felicito.app",
                          # Legacy domain: keep until old clients/bookmarks have moved over.
                          "https://admin-staging.cardjoy.app",
                          "https://staging.cardjoy.app"
                        ]
    when "production"
                        [
                          "https://felicito.app",
                          "https://admin.felicito.app",
                          # Legacy domain (301-forwards to felicito.app, but old cached bundles
                          # may still call the API from here). Remove after the transition.
                          "https://cardjoy.app",
                          "https://admin.cardjoy.app"
                        ]
    else
                        # dev or test
                        [
                          "http://localhost:3001",
                          "http://localhost:3002"
                        ]
    end

    # Extra allowed origins from the environment, comma-separated.
    extra_origins = ENV.fetch("ADDITIONAL_CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
    allowed_origins += extra_origins

    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :options, :delete, :put, :patch ],
      credentials: true
  end
end
