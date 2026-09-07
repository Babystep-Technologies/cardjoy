# typed: true
# frozen_string_literal: true

# PostGrid — the print-and-mail vendor that turns a holiday card into something
# a letter carrier delivers (issue #142).
#
# This module owns two things: credential resolution and the error hierarchy.
# The HTTP itself lives in PostGrid::Client.
#
# ## Why `mode:` is always explicit
#
# PostGrid issues two keys per account, `live_sk_…` and `test_sk_…`. Which one a
# call uses is a *product* decision, not an environment one, so nothing here
# ever looks at `Rails.env`. The proof run deliberately exercises the test key
# from production, and an implicit `Rails.env.production? ? live : test` would
# make that impossible to express — worse, it would make a staging box that
# happens to boot as `production` mail real postcards.
#
# So every entry point takes `mode:`. `PostGrid.default_mode` reads
# `POSTGRID_MODE` for callers that have no opinion (the GraphQL layer), and
# defaults to `:test` — the safe direction to be wrong in, since a misconfigured
# deploy then fails to mail rather than silently billing someone.
#
# ## Configuration
#
# Per CLAUDE.md, config reads from the environment with a Rails credentials
# fallback, so local dev needs no secret:
#
#   POSTGRID_API_KEY        → credentials.post_grid.api_key        (live_sk_…)
#   POSTGRID_TEST_API_KEY   → credentials.post_grid.test_api_key   (test_sk_…)
#   POSTGRID_MODE           → credentials.post_grid.mode           ("live" | "test")
#   POSTGRID_WEBHOOK_SECRET → credentials.post_grid.webhook_secret (webhook signing)
#
# **This repo is public. No key, live or test, is ever committed.** The test
# credentials file carries a dummy value only.
module PostGrid
  extend T::Sig

  MODES = %i[live test].freeze

  # Mailing to a physical address is the kind of feature that should switch off
  # rather than explode when it isn't set up — the same gating GIPHY, Unsplash,
  # and PostHog get on the frontend. Callers ask `configured?` and degrade.
  DEFAULT_MODE = :test

  # Base of the error hierarchy. Every failure a caller can see is one of the
  # four subclasses below, because the mail-order job branches on them: it
  # retries one kind and refunds on the other. A bare `StandardError` leaking
  # out of here would be refunded when it should have been retried.
  class Error < StandardError
    extend T::Sig

    attr_reader :status, :error_code

    def initialize(message = nil, status: nil, error_code: nil)
      @status = status
      @error_code = error_code
      super(message)
    end

    # Whether trying the exact same request again could plausibly succeed.
    # False here, true on the retryable subclasses. The client's retry loop and
    # the job's refund decision both read this rather than matching on class,
    # so adding an error class later can't silently become non-retryable.
    def retryable?
      false
    end
  end

  # No usable API key for the requested mode. Raised by the client rather than
  # returned, because a caller that checked `configured?` first can't hit it.
  class ConfigurationError < Error; end

  # 401/403 — the key is missing, wrong, or revoked. Never retried: a bad key
  # stays bad, and hammering an auth endpoint is how you get rate limited.
  class AuthenticationError < Error; end

  # 4xx other than 401/403/429 — we sent something PostGrid rejected
  # (undeliverable address, bad size, missing field). Our bug or the user's
  # input; replaying it verbatim just fails again.
  class InvalidRequestError < Error; end

  # 429. Retryable, and the one case where PostGrid tells us how long to wait.
  class RateLimitError < Error
    def retryable?
      true
    end
  end

  # 5xx, connection failure, or timeout — PostGrid is unwell, we are fine.
  # Safe to retry: either the request never landed, or the create is guarded by
  # the caller's Idempotency-Key.
  class ServiceError < Error
    def retryable?
      true
    end
  end

  class << self
    extend T::Sig

    # The API key for `mode`, or nil when none is configured.
    sig { params(mode: Symbol).returns(T.nilable(String)) }
    def api_key(mode:)
      case validated_mode(mode)
      when :live
        env_or_credential("POSTGRID_API_KEY", :api_key)
      else
        env_or_credential("POSTGRID_TEST_API_KEY", :test_api_key)
      end
    end

    # False when no key is present for `mode`. Callers gate on this and degrade
    # to "physical mail unavailable" rather than raising — nothing in the app
    # may crash just because PostGrid isn't set up, which is the normal state
    # of every local clone and of CI.
    sig { params(mode: Symbol).returns(T::Boolean) }
    def configured?(mode: default_mode)
      api_key(mode:).present?
    end

    # The secret PostGrid signs webhook deliveries with, or nil when none is
    # configured. It is per-webhook rather than per-mode — PostGrid shows it
    # once, when the webhook endpoint is created — so unlike the API keys it
    # takes no `mode:`.
    #
    # Nil is not "skip verification": PostgridWebhooksController rejects every
    # request with 401 when this is unset, because an endpoint that mutates
    # order state and issues refunds is not one to leave open on a box that
    # forgot to configure it.
    sig { returns(T.nilable(String)) }
    def webhook_secret
      env_or_credential("POSTGRID_WEBHOOK_SECRET", :webhook_secret)
    end

    # The mode to use when the caller has no reason to prefer one. Anything
    # that isn't exactly "live" is treated as test, so a typo in the env var
    # can't promote a deploy to mailing real cards.
    sig { returns(Symbol) }
    def default_mode
      configured = env_or_credential("POSTGRID_MODE", :mode)
      configured.to_s.strip.downcase == "live" ? :live : DEFAULT_MODE
    end

    private

    sig { params(mode: T.untyped).returns(Symbol) }
    def validated_mode(mode)
      symbol = mode.to_sym
      raise ArgumentError, "Unknown PostGrid mode #{mode.inspect}" unless MODES.include?(symbol)

      symbol
    end

    # ENV first, encrypted credentials second — the convention the rest of the
    # app follows (see AppConfig, config/database.yml, the Google sign-in
    # mutations). Blank is treated as unset so an empty env var in a compose
    # file reads as "not configured" rather than as a key of "".
    sig { params(env_key: String, credential_key: Symbol).returns(T.nilable(String)) }
    def env_or_credential(env_key, credential_key)
      ENV[env_key].presence || Rails.application.credentials.dig(:post_grid, credential_key).presence
    end
  end
end
