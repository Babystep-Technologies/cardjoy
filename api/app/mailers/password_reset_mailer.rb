# typed: true

class PasswordResetMailer < ApplicationMailer
  def send_reset_email
    @user = params[:user]
    @token = params[:token]
    @reset_url = "#{Rails.application.credentials.dig(:frontend_url)}/reset_password?token=#{@token}"

    mail(to: @user.email, subject: "Password Reset Instructions")
  end
end
