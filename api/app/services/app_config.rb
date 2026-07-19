# typed: true
# frozen_string_literal: true

# Central resolver for runtime app configuration that varies by environment.
#
# `frontend_url` is the public base URL of the consumer web app. It's read from
# the FRONTEND_URL env var, falling back to Rails encrypted credentials, then to
# the local web dev server. Without the dev fallback the credential is `nil` in
# local development, which turned preview redirects (and mailer links) into bare
# paths like "/card/:id/viewable" that resolve against the *API* host and 404 —
# see PreviewsController.
module AppConfig
  extend T::Sig

  # `make dev` serves the web app on :3001.
  DEVELOPMENT_FRONTEND_URL = "http://localhost:3001"

  sig { returns(T.nilable(String)) }
  def self.frontend_url
    ENV.fetch("FRONTEND_URL") do
      Rails.application.credentials.dig(:frontend_url) ||
        (Rails.env.development? ? DEVELOPMENT_FRONTEND_URL : nil)
    end
  end
end
