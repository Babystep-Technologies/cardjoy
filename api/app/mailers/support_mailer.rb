# typed: true

class SupportMailer < ApplicationMailer
  def send_case_email(reason, message, user_email)
    mail(
      to: "team.cardjoy@gmail.com",
      reply_to: user_email,
      subject: "[Customer Request] #{reason}",
      body: message
    )
  end
end
