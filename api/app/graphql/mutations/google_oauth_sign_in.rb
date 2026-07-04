# typed: true

module Mutations
  class GoogleOauthSignIn < BaseMutation
    argument :id_token, String, required: true

    field :user, Types::UserType, null: true
    field :token, String, null: true
    field :errors, [ String ], null: false

    def resolve(id_token:)
      # Validate the Google id_token (using an appropriate gem or custom code)
      # For instance, using the google-id-token gem:
      validator = GoogleIDToken::Validator.new
      google_client_id = Rails.application.credentials.dig(:google, :client_id)
      payload = validator.check(id_token, google_client_id) rescue nil

      if payload
        user = User.from_google(
          uid: payload["sub"],
          email: payload["email"],
          full_name: payload["name"]
        )
        token = JWT.encode({
            user_id: user.id,
            exp: 6.months.from_now.to_i,
            name: payload["name"],
            email: payload["email"]
          }, Rails.application.credentials.dig(:jwt, :secret)
        )
        {
          user: user,
          token: token,
          errors: []
        }
      else
        {
          user: nil,
          token: nil,
          errors: [ "Invalid Google token" ]
        }
      end
    end
  end
end
