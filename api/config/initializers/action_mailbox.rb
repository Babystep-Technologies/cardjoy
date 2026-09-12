# Which inbound-mail provider (#174) is allowed to post to
# /rails/action_mailbox/*/inbound_emails — :sendgrid, :postmark, :mailgun, or
# :relay. Chosen by env with credential fallback (AppConfig.inbound_email_ingress);
# unset means every ingress request 404s instead of accepting mail from nowhere.
#
# Must go in a `to_prepare` block: the Zeitwerk autoloader isn't ready yet
# while config/environments/*.rb OR config/initializers/*.rb are evaluated
# (it's set up in the Finisher phase, which runs after both) — referencing
# AppConfig directly in either raises `NameError: uninitialized constant
# AppConfig`. `to_prepare` runs once boot's autoloader setup is done.
Rails.application.config.to_prepare do
  Rails.application.config.action_mailbox.ingress = AppConfig.inbound_email_ingress
end
