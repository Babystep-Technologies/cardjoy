# typed: strict

module Mutations
  class ConfirmEmail < BaseMutation
    extend T::Sig

    class Response < T::Struct
      const :user, T.nilable(User)
      const :token, T.nilable(String)
      const :errors, T::Array[String]
    end

    argument :email, String, required: true
    argument :code, String, required: true

    field :user, Types::UserType, null: true
    field :token, String, null: true
    field :errors, [ String ], null: false

    sig { params(email: String, code: String).returns(Response) }
    def resolve(email:, code:)
      user = User.find_by(email: email)

      return Response.new(user: nil, token: nil, errors: [ "User not found" ]) unless user
      return Response.new(user: nil, token: nil, errors: [ "Already verified" ]) if user.email_confirmed
      return Response.new(user: nil, token: nil, errors: [ "Code expired" ]) if user.confirmation_code_expired?
      return Response.new(user: nil, token: nil, errors: [ "Invalid code" ]) unless user.confirmation_code == code

      user.confirm_email!(code)

      token = JWT.encode(
        {
          user_id: user.id,
          exp: 1.day.from_now.to_i,
          name: user.name,
          email: user.email
        },
        Rails.application.credentials.dig(:jwt, :secret)
      )

      Response.new(user: user, token: token, errors: [])
    end
  end
end
