# typed: true

module Mutations
  class ResendConfirmationCode < BaseMutation
    argument :email, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(email:)
      user = User.find_by(email: email.downcase)

      if user.nil?
        return { success: false, errors: [ "User not found" ] }
      end

      if user.email_confirmed?
        return { success: false, errors: [ "Email is already confirmed" ] }
      end

      if user.provider == "google_oauth2"
        return { success: false, errors: [ "Google sign-ins do not require confirmation" ] }
      end

      user.generate_confirmation_code!
      { success: true, errors: [] }
    rescue => e
      { success: false, errors: [ e.message ] }
    end
  end
end
