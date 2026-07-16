# typed: true

module Mutations
  class ConnectSlackAccount < BaseMutation
    argument :state, String, required: true

    field :success, Boolean, null: false
    field :errors, [ String ], null: false

    def resolve(state:)
      user = context[:current_user]
      return { success: false, errors: [ "Not authenticated" ] } unless user

      payload = JWT.decode(
        state,
        Rails.configuration.x.jwt_secret,
        true,
        { algorithm: "HS256" }
      ).first

      slack_user_id = payload["slack_user_id"]
      slack_team_id = payload["slack_team_id"]

      connection = SlackUserConnection.find_or_initialize_by(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id
      )
      connection.user = user
      connection.save!

      { success: true, errors: [] }
    rescue JWT::ExpiredSignature
      { success: false, errors: [ "Connection link has expired. Please run /cardjoy again in Slack." ] }
    rescue JWT::DecodeError
      { success: false, errors: [ "Invalid connection link." ] }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, errors: e.record.errors.full_messages }
    end
  end
end
