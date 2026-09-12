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

  # The domain a SupportTicket's `support+<token>@` reply address is addressed
  # at (#174). This is deliberately not tied to the Gmail SMTP address
  # ApplicationMailer sends from (production.rb) — outbound mail and inbound
  # mail are configured independently, and only the domain here needs MX
  # records pointing at whichever ingress `inbound_email_ingress` selects.
  sig { returns(String) }
  def self.support_inbound_email_domain
    ENV.fetch("SUPPORT_INBOUND_EMAIL_DOMAIN", "cardjoy.app")
  end

  # Which Action Mailbox ingress controller is allowed to post inbound mail
  # (#174) — :sendgrid, :postmark, :mailgun, or :relay. nil (the default) means
  # unconfigured, which makes every ingress endpoint 404 rather than accept
  # mail from nowhere — the same "absent key degrades, never crashes" shape as
  # PostGrid.configured?. The provider account and its DNS live outside this
  # repo; see the PR for #174.
  sig { returns(T.nilable(Symbol)) }
  def self.inbound_email_ingress
    value = ENV["RAILS_INBOUND_EMAIL_INGRESS"].presence ||
            Rails.application.credentials.dig(:action_mailbox, :ingress).presence
    value&.to_sym
  end
end
