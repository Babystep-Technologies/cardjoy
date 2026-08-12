# typed: true

require "net/http"
require "uri"

class ApplicationMailer < ActionMailer::Base
  # `From` stays CardJoy on every send, including organization-branded ones —
  # see MailerBrand#reply_to for why.
  default from: "CardJoy <team.cardjoy@gmail.com>"
  layout "mailer"

  before_action :set_default_brand

  private

  # Every email gets CardJoy's own branding unless a mailer replaces it. Account
  # mail (UserMailer, PasswordResetMailer) is about the CardJoy account rather
  # than any organization, so it deliberately never calls the setter below.
  def set_default_brand
    @brand = MailerBrand.new
  end

  # Rebrand this message for `organization`. nil is meaningful and expected — a
  # personal card has no organization — and falls back to CardJoy's branding.
  def set_organization_brand(organization)
    @brand = MailerBrand.new(organization: organization)
  end

  # Splatted into `mail` by org-aware mailers. Absent rather than nil when the
  # organization sets no reply-to, so the header simply isn't written.
  def brand_reply_to
    reply_to = @brand&.reply_to
    reply_to ? { reply_to: reply_to } : {}
  end
end
