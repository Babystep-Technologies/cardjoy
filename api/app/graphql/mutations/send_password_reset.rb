# typed: true

module Mutations
  class SendPasswordReset < BaseMutation
    argument :email, String, required: true

    field :success, Boolean, null: false

    def resolve(email:)
      user = User.find_by(email: email)
      return { success: false } unless user

      # Generate reset token
      token = SecureRandom.hex(20)
      user.update(reset_password_token: token, reset_password_sent_at: Time.now.utc)

      # Send reset email
      PasswordResetMailer.with(user: user, token: token).send_reset_email.deliver_later

      { success: true }
    end
  end
end
