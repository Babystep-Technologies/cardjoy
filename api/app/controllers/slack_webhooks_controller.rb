# typed: true

class SlackWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  SLACK_OCCASIONS = [
    "First day at work",
    "Last day at work",
    "Promotion at work",
    "Work anniversary"
  ].freeze

  OCCASION_TITLES = {
    "First day at work"  => "Welcome to the team, %{name}!",
    "Last day at work"   => "We'll miss you, %{name}!",
    "Promotion at work"  => "Congrats on the promotion, %{name}!",
    "Work anniversary"   => "Happy work anniversary, %{name}!"
  }.freeze

  OCCASION_COVER_TAGS = {
    "First day at work"  => "first-day-at-work",
    "Last day at work"   => "last-day-at-work",
    "Promotion at work"  => "promotion-at-work",
    "Work anniversary"   => "work-anniversary"
  }.freeze

  def create
    # Parse JSON body explicitly — Slack sends url_verification as application/json
    json_body = begin
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      {}
    end

    # Slack URL verification challenge (sent once when setting up Event Subscriptions)
    type = params[:type] || json_body["type"]
    if type == "url_verification"
      challenge = params[:challenge] || json_body["challenge"]
      render json: { challenge: challenge } and return
    end

    return render json: { error: "Unauthorized" }, status: :unauthorized unless valid_slack_signature?

    # Modal submission comes as JSON in the `payload` param
    if params[:payload].present?
      payload = JSON.parse(params[:payload])
      if payload["type"] == "view_submission"
        handle_view_submission(payload)
      else
        render json: { ok: true }
      end
      return
    end

    # Events API (app_uninstalled, tokens_revoked)
    if params[:type] == "event_callback"
      handle_event(params[:event])
      render json: { ok: true } and return
    end

    # Slash command
    handle_slash_command
  end

  private

  # ------------------------------------------------------------------
  # Slash command — open the modal
  # ------------------------------------------------------------------

  def handle_slash_command
    slack_user_id = params[:user_id]
    slack_team_id = params[:team_id]
    trigger_id    = params[:trigger_id]

    installation = SlackInstallation.find_by(team_id: slack_team_id)
    unless installation
      render json: {
        response_type: "ephemeral",
        text: "CardJoy is not installed in this workspace. Please ask a workspace admin to install it."
      } and return
    end

    connection = SlackUserConnection.find_by(slack_user_id: slack_user_id, slack_team_id: slack_team_id)

    unless connection
      profile = fetch_slack_user_profile(slack_user_id, T.must(installation).access_token)
      user = User.from_slack(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        email: profile[:email],
        name: profile[:name]
      )

      # No email on the Slack profile (mainly Slack Connect / external guests):
      # we no longer synthesize a shadow account. Prompt the user to connect a
      # real CardJoy account and stop here — the modal opens once they're
      # connected and re-run /cardjoy. See issue #81.
      unless user
        render json: {
          response_type: "ephemeral",
          text: connect_prompt_text(slack_user_id, slack_team_id)
        } and return
      end

      connection = SlackUserConnection.create!(
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        user: user
      )
    end

    open_modal(trigger_id, slack_team_id, params[:response_url])
    head :ok
  end

  # ------------------------------------------------------------------
  # Modal submission — create the card
  # ------------------------------------------------------------------

  def handle_view_submission(payload)
    slack_user_id = payload.dig("user", "id")
    slack_team_id = payload.dig("user", "team_id")
    values        = payload.dig("view", "state", "values") || {}

    recipient_slack_id = values.dig("recipient_block", "recipient_user", "selected_user")
    occasion           = values.dig("occasion_block", "occasion_select", "selected_option", "value")

    connection = SlackUserConnection.find_by(slack_user_id: slack_user_id, slack_team_id: slack_team_id)
    unless connection
      render json: { response_action: "errors", errors: { recipient_block: "Your Cardjoy account is not connected." } } and return
    end

    installation = SlackInstallation.find_by(team_id: slack_team_id)
    recipient_name = fetch_slack_user_name(recipient_slack_id, installation&.access_token) if recipient_slack_id

    user = T.must(T.must(connection).user)

    card = T.let(nil, T.nilable(Card))
    ApplicationRecord.transaction do
      # Debit first so an insufficient balance blocks creation before we do any
      # image work; the whole transaction rolls back if anything fails, so a
      # failed create never burns a credit. Mirrors Mutations::CreateCard so the
      # Slack flow keeps the credit ledger consistent with the web app.
      user.spend_credit!(reason: "card_created", event_kind: "card_created")

      card = Card.create!(
        user: user,
        title: card_title_for(occasion, recipient_name),
        recipients: [ recipient_name ],
        occasion: occasion
      )
      attach_default_cover_image(card, occasion)
    end
    card = T.must(card)

    card_path = card.slug.presence || card.external_id
    token = generate_auth_token(user)
    card_url = "#{frontend_url}/card/#{card_path}/editable?token=#{token}"

    # Close the modal and post a follow-up message via response_url
    # Use <@slack_id> so Slack auto-resolves the display name
    response_url = payload.dig("view", "private_metadata")
    if response_url.present?
      post_response_url(response_url, "Card for <@#{recipient_slack_id}> created! :tada: <#{card_url}|See card>")
    end

    render json: { response_action: "clear" }
  rescue User::InsufficientCreditsError
    # The modal can only show plain text, so the actual purchase link goes out as
    # a follow-up message with a "Buy credits" button. See issue #83.
    post_buy_credits_prompt(payload.dig("view", "private_metadata"), user)

    render json: {
      response_action: "errors",
      errors: { recipient_block: "You're out of CardJoy credits. Check the message from CardJoy in Slack to buy more, then try again." }
    }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[SlackWebhook] Card creation failed: #{e.message}")
    render json: { response_action: "errors", errors: { recipient_block: "Failed to create card. Please try again." } }
  end

  # ------------------------------------------------------------------
  # Events API
  # ------------------------------------------------------------------

  def handle_event(event)
    case event["type"]
    when "app_uninstalled"
      team_id = params[:team_id]
      SlackInstallation.find_by(team_id: team_id)&.destroy
      SlackUserConnection.where(slack_team_id: team_id).destroy_all
    when "tokens_revoked"
      team_id = params[:team_id]
      revoked_user_ids = event.dig("tokens", "oauth") || []
      SlackUserConnection.where(slack_team_id: team_id, slack_user_id: revoked_user_ids).destroy_all
    end
  end

  # ------------------------------------------------------------------
  # Slack API helpers
  # ------------------------------------------------------------------

  def card_title_for(occasion, recipient_name)
    template = OCCASION_TITLES[occasion]
    return "Card for #{recipient_name}" unless template

    template % { name: recipient_name }
  end

  def attach_default_cover_image(card, occasion)
    tag_name = OCCASION_COVER_TAGS[occasion]
    return unless tag_name

    style = Style.joins(:tags)
                 .where(tags: { name: tag_name }, kind: "cover")
                 .where(deleted_at: nil)
                 .first
    return unless style&.image&.attached?

    style = T.must(style)
    blob = T.unsafe(style.image).blob
    card.cover_image.attach(
      io: StringIO.new(blob.download),
      filename: blob.filename.to_s,
      content_type: blob.content_type
    )
  end

  def open_modal(trigger_id, slack_team_id, response_url)
    installation = SlackInstallation.find_by(team_id: slack_team_id)
    return unless installation

    slack_post(
      "https://slack.com/api/views.open",
      installation.access_token,
      {
        trigger_id: trigger_id,
        view: modal_payload(response_url)
      }
    )
  end

  def modal_payload(response_url)
    {
      type: "modal",
      callback_id: "create_card",
      private_metadata: response_url.to_s,
      title: { type: "plain_text", text: "Create a Group Card" },
      submit: { type: "plain_text", text: "Create Card" },
      close: { type: "plain_text", text: "Cancel" },
      blocks: [
        {
          type: "input",
          block_id: "recipient_block",
          label: { type: "plain_text", text: "Who is this card for?" },
          element: {
            type: "users_select",
            action_id: "recipient_user",
            placeholder: { type: "plain_text", text: "Select a person" }
          }
        },
        {
          type: "input",
          block_id: "occasion_block",
          label: { type: "plain_text", text: "What is the occasion?" },
          element: {
            type: "static_select",
            action_id: "occasion_select",
            placeholder: { type: "plain_text", text: "Select an occasion" },
            options: SLACK_OCCASIONS.map do |occasion|
              { text: { type: "plain_text", text: occasion }, value: occasion }
            end
          }
        }
      ]
    }
  end

  def fetch_slack_user_name(slack_user_id, bot_token)
    profile = fetch_slack_user_profile(slack_user_id, bot_token)
    profile[:name] || slack_user_id
  end

  def fetch_slack_user_profile(slack_user_id, bot_token)
    return { name: nil, email: nil } if bot_token.blank?

    uri = URI("https://slack.com/api/users.info?user=#{slack_user_id}")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{bot_token}"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    body = JSON.parse(http.request(req).body)

    unless body["ok"]
      Rails.logger.error("[SlackAPI] users.info failed for #{slack_user_id}: #{body['error']}")
      return { name: nil, email: nil }
    end

    name = body.dig("user", "profile", "display_name").presence ||
           body.dig("user", "profile", "real_name").presence ||
           body.dig("user", "real_name").presence ||
           body.dig("user", "name").presence
    email = body.dig("user", "profile", "email").presence

    { name: name, email: email }
  end

  def post_response_url(url, text, response_type: "in_channel", blocks: nil)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    body = { response_type: response_type, text: text, mrkdwn: true }
    body[:blocks] = blocks if blocks
    req.body = body.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.request(req)
  end

  def slack_post(url, bot_token, body)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{bot_token}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.request(req)
  end

  # ------------------------------------------------------------------
  # Auth / misc helpers
  # ------------------------------------------------------------------

  def valid_slack_signature?
    timestamp   = request.headers["X-Slack-Request-Timestamp"]
    slack_sig   = request.headers["X-Slack-Signature"]
    signing_secret = Rails.application.credentials.dig(:slack, :signing_secret)

    base     = "v0:#{timestamp}:#{request.raw_post}"
    expected = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, base)

    ActiveSupport::SecurityUtils.secure_compare(expected, slack_sig.to_s)
  end

  # Message shown when a Slack user has no profile email and can't be
  # auto-provisioned. Links to the connect flow with a short-lived signed state
  # token that ConnectSlackAccount decodes to link their real CardJoy account.
  def connect_prompt_text(slack_user_id, slack_team_id)
    connect_url = "#{frontend_url}/connect-slack?state=#{connect_state_token(slack_user_id, slack_team_id)}"
    "Before you can create a card, connect your CardJoy account: " \
      "<#{connect_url}|Connect CardJoy>. Once connected, run `/cardjoy` again."
  end

  # Follow-up message shown when a card creation is blocked for insufficient
  # credits. The button carries the same 24h auth token we use for the editable
  # card link, so the user lands on /buy_credits already signed in and the normal
  # Stripe checkout flow credits their account. Always ephemeral — the token
  # authenticates as this user and must not be visible to the rest of the channel.
  def post_buy_credits_prompt(response_url, user)
    return if response_url.blank?

    buy_credits_url =
      "#{frontend_url}/buy_credits?reason=insufficient_balance&token=#{generate_auth_token(user)}"
    text = "You're out of CardJoy credits, so that card wasn't created. " \
           "Buy more credits and run `/cardjoy` again."

    post_response_url(
      response_url,
      text,
      response_type: "ephemeral",
      blocks: [
        { type: "section", text: { type: "mrkdwn", text: text } },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              action_id: "buy_credits",
              style: "primary",
              text: { type: "plain_text", text: "Buy credits" },
              url: buy_credits_url
            }
          ]
        }
      ]
    )
  rescue StandardError => e
    # Never let a failed follow-up swallow the in-modal error the user needs.
    Rails.logger.error("[SlackWebhook] Buy credits prompt failed: #{e.message}")
  end

  def connect_state_token(slack_user_id, slack_team_id)
    JWT.encode(
      {
        slack_user_id: slack_user_id,
        slack_team_id: slack_team_id,
        exp: 1.hour.from_now.to_i
      },
      Rails.configuration.x.jwt_secret,
      "HS256"
    )
  end

  def generate_auth_token(user)
    JWT.encode(
      {
        user_id: user.id,
        exp: 24.hours.from_now.to_i,
        name: user.name,
        email: user.email
      },
      Rails.configuration.x.jwt_secret
    )
  end

  def frontend_url
    Rails.application.credentials.dig(:frontend_url)
  end

  def preview_url
    Rails.application.config.x.preview_url
  end
end
