Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = case Rails.env
    when "staging"
                        [
                          "https://admin-staging.cardjoy.app",
                          "https://staging.cardjoy.app"
                        ]
    when "production"
                        [
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

    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :options, :delete, :put, :patch ],
      credentials: true
  end
end
