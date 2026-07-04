# typed: true

module Mutations
  class ResetPassword < BaseMutation
    argument :token, String, required: true
    argument :password, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: true

    def resolve(token:, password:)
      user = User.find_by(reset_password_token: token)

      return { success: false, errors: [ "Invalid or expired token" ] } unless user
      return { success: false, errors: [ "Token expired" ] } if T.must(user.reset_password_sent_at) < 2.hours.ago

      # Update password
      if user.update(password: password, reset_password_token: nil, reset_password_sent_at: nil)
        { success: true, errors: [] }
      else
        { success: false, errors: user.errors.full_messages }
      end
    end
  end
end
