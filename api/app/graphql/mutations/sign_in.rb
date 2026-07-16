# typed: false

module Mutations
  class SignIn < BaseMutation
    argument :email, String, required: true
    argument :password, String, required: true

    field :user, Types::UserType, null: true
    field :token, String, null: true
    field :errors, [ String ], null: false
    field :email_confirmation_required, Boolean, null: false

    def resolve(email:, password:)
      user = User.find_by(email: email)

      unless user&.valid_password?(password)
        return {
          user: nil,
          token: nil,
          errors: [ "Invalid credentials" ],
          email_confirmation_required: false
        }
      end

      unless user.email_confirmed?
        return {
          user: nil,
          token: nil,
          errors: [ "Email not confirmed. Please enter the 6-digit code we emailed you." ],
          email_confirmation_required: true
        }
      end

      token = JWT.encode({
          user_id: user.id,
          exp: 6.months.from_now.to_i,
          name: user.name,
          email: user.email
        }, Rails.configuration.x.jwt_secret)

      context[:response].set_cookie(:auth_token, {
        value: token,
        httponly: true,
        secure: true,
        same_site: :none,
        domain: :all
      })

      {
        user: user,
        token: token,
        errors: [],
        email_confirmation_required: false
      }
    end
  end
end
