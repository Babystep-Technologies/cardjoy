# typed: true

module Mutations
  class GoogleAdminSignIn < BaseMutation
    argument :id_token, String, required: true

    field :admin, Types::AdminType, null: true
    field :token, String, null: true
    field :errors, [ String ], null: false

    def resolve(id_token:)
      validator = GoogleIDToken::Validator.new
      google_client_id = ENV.fetch("GOOGLE_CLIENT_ID") { Rails.application.credentials.dig(:google, :client_id) }
      payload = validator.check(id_token, google_client_id) rescue nil
      jwt_secret = Rails.configuration.x.jwt_secret

      if payload
        admin = Admin.from_google(
          uid: payload["sub"],
          email: payload["email"],
          name: payload["name"]
        )

        token = JWT.encode({
          admin_id: admin.id,
          exp: 6.months.from_now.to_i,
          name: payload["name"],
          email: payload["email"]
        }, jwt_secret)

        {
          admin: admin,
          token: token,
          errors: []
        }
      else
        {
          admin: nil,
          token: nil,
          errors: [ "Invalid Google token" ]
        }
      end
    end
  end
end
