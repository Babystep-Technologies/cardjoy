# typed: true

module Mutations
  class SignUp < BaseMutation
    argument :name, String, required: true
    argument :email, String, required: true
    argument :password, String, required: true

    field :user, Types::UserType, null: true
    field :token, String, null: true
    field :errors, [ String ], null: false
    field :email_confirmation_required, Boolean, null: false

    def resolve(name:, email:, password:)
      if User.exists?(email: email)
        return {
          user: nil,
          token: nil,
          errors: [ "User already exists" ],
          email_confirmation_required: false
        }
      end

      user = User.new(name: name, email: email, password: password)

      if user.save
        user.generate_confirmation_code!

        {
          user: user,
          token: nil, # Don't issue token yet
          errors: [],
          email_confirmation_required: true
        }
      else
        {
          user: nil,
          token: nil,
          errors: user.errors.full_messages,
          email_confirmation_required: false
        }
      end
    end
  end
end
