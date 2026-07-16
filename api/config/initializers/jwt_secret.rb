# typed: false
# frozen_string_literal: true

# Refuse to boot without a JWT signing secret.
#
# `JWT.encode` signs happily with a nil key, so a missing secret does not fail —
# it degrades. `signIn` returns a token and reports success, then every later
# request fails verification with "No verification key available", gets rescued
# into an anonymous request, and mutations report a misleading "Not
# authenticated". A server misconfiguration is not a client problem, and this
# one leaves no trace pointing at the cause.
#
# This lives in config/initializers rather than config/application.rb on
# purpose: `credentials:edit` loads application.rb but only runs :all-group
# initializers, so checking here still leaves you able to add the very secret
# that is missing.
if Rails.configuration.x.jwt_secret.blank?
  raise <<~MESSAGE
    JWT signing secret is missing, so no token this app issues could be verified.

    Set it one of two ways (see docs/DEVELOPMENT.md):
      * JWT_SECRET_KEY env var — how local development is wired, in docker-compose.yml.
      * jwt.secret in the #{Rails.env} credentials — `bin/rails credentials:edit --environment #{Rails.env}`.
  MESSAGE
end
