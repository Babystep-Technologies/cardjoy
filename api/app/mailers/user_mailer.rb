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
end
