# typed: true

class UserMailer < ApplicationMailer
  def confirmation_code(user:)
    @user = user
    mail(to: user.email, subject: "Your CardJoy Confirmation Code")
  end

  def purchase_confirmation_email(user, amount)
    @user = user
    @amount = amount
    mail(to: @user.email, subject: "Thanks for your purchase — #{amount} credits added!")
  end

  def promo_code_issued(user:, promo_code:)
    @user = user
    @promo_code = promo_code
    @redeem_url = "#{Rails.application.credentials.dig(:frontend_url)}/redeem?code=#{promo_code.code}"
    mail(to: user.email, subject: "You've received CardJoy credits 🎁")
  end
end
