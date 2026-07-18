# typed: true
# frozen_string_literal: true

class GraphqlController < ApiController
  # Operations that must work without authentication (sign-in/sign-up, the public
  # card reveal + guest messaging, RSVP, and the cover-style/occasion pickers used
  # before login). Matched exactly against the incoming operationName — a substring
  # match would let any operation whose name merely *contains* one of these (e.g.
  # "UpdateCard" contains "Card") skip the controller-level auth gate.
  PUBLIC_OPERATIONS = %w[
    SignIn SignUp GoogleOauthSignIn SendPasswordReset GoogleAdminSignIn
    Card UpsertMessage ResendConfirmationCode ConfirmEmail ResetPassword
    GetOccasions GetStyles CreateRsvp GetInvitation
  ].freeze

  use ApolloUploadServer::Middleware

  before_action :set_current_user_or_admin
  before_action :authenticate_user_with_graphql!, unless: :public_operation?

  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: @current_user,
      current_admin: @current_admin
    }.merge(response: response)
    result = ApiSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end

  def set_current_user_or_admin
    token = request.headers["Authorization"]&.split(" ")&.last
    return unless token

    begin
      decoded_token = JWT.decode(token, Rails.configuration.x.jwt_secret, true, algorithm: "HS256")
      payload = decoded_token[0]

      if payload["user_id"]
        @current_user = User.find_by(id: payload["user_id"])
      elsif payload["admin_id"]
        @current_admin = Admin.find_by(id: payload["admin_id"])
      end
    rescue JWT::DecodeError => e
      # A malformed or expired token from a client is a client problem: treat the
      # request as anonymous rather than raising. Log it so that never happens
      # silently — a JWT::VerificationError here means tokens are signed with a
      # different secret than this process holds, which no client can cause.
      Rails.logger.warn("Ignoring unverifiable JWT (#{e.class}): #{e.message}")
      @current_user = nil
      @current_admin = nil
    end
  end

  def authenticate_user_with_graphql!
    unless @current_user || @current_admin
      render json: { errors: [ "Unauthorized" ] }, status: :unauthorized
    end
  end

  def public_operation?
    PUBLIC_OPERATIONS.include?(params[:operationName].to_s)
  end
end
