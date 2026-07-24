require 'rails_helper'

RSpec.describe "SlackWebhooks", type: :request do
  let(:signing_secret) { "test_slack_signing_secret" }
  let(:frontend_url) { "https://app.cardjoy.test" }
  let(:preview_url) { "https://preview.cardjoy.test" }
  let(:jwt_secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:slack, :signing_secret).and_return(signing_secret)
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(frontend_url)
    allow(Rails.application.credentials).to receive(:dig).with(:preview_url).and_return(preview_url)
    allow(Rails.application.credentials).to receive(:dig).with(:jwt, :secret).and_return(jwt_secret)
  end

  def slack_headers(body)
    timestamp = Time.now.to_i.to_s
    base = "v0:#{timestamp}:#{body}"
    sig = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, base)
    {
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature" => sig
    }
  end

  def post_slash_command(params)
    body = params.to_query
    post "/webhooks/slack",
      params: body,
      headers: slack_headers(body).merge("Content-Type" => "application/x-www-form-urlencoded")
  end

  def post_event(payload)
    body = payload.to_json
    post "/webhooks/slack",
      params: body,
      headers: slack_headers(body).merge("Content-Type" => "application/json")
  end

  def post_modal_submission(payload_hash)
    body = { payload: payload_hash.to_json }.to_query
    post "/webhooks/slack",
      params: body,
      headers: slack_headers(body).merge("Content-Type" => "application/x-www-form-urlencoded")
  end

  def stub_slack_views_open
    stub_request(:post, "https://slack.com/api/views.open")
      .to_return(status: 200, body: '{"ok":true}')
  end

  def stub_slack_users_info(slack_user_id, display_name, email: nil)
    profile = { display_name: display_name, real_name: display_name }
    profile[:email] = email if email
    stub_request(:get, "https://slack.com/api/users.info?user=#{slack_user_id}")
      .to_return(
        status: 200,
        body: { ok: true, user: { profile: profile } }.to_json
      )
  end

  # ------------------------------------------------------------------
  # URL verification
  # ------------------------------------------------------------------

  describe "URL verification" do
    it "responds with the challenge" do
      post "/webhooks/slack",
        params: { type: "url_verification", challenge: "abc123" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["challenge"]).to eq("abc123")
    end
  end

  # ------------------------------------------------------------------
  # Signature verification
  # ------------------------------------------------------------------

  describe "signature verification" do
    it "rejects slash commands with an invalid signature" do
      body = { user_id: "U123", team_id: "T456" }.to_query
      post "/webhooks/slack",
        params: body,
        headers: {
          "X-Slack-Request-Timestamp" => Time.now.to_i.to_s,
          "X-Slack-Signature" => "v0=invalidsignature",
          "Content-Type" => "application/x-www-form-urlencoded"
        }

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects modal submissions with an invalid signature" do
      body = { payload: { type: "view_submission" }.to_json }.to_query
      post "/webhooks/slack",
        params: body,
        headers: {
          "X-Slack-Request-Timestamp" => Time.now.to_i.to_s,
          "X-Slack-Signature" => "v0=invalidsignature",
          "Content-Type" => "application/x-www-form-urlencoded"
        }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ------------------------------------------------------------------
  # Slash command — opens modal
  # ------------------------------------------------------------------

  describe "slash command" do
    let(:user) { create(:user) }
    let(:team_id) { "T12345" }
    let(:slack_user_id) { "U67890" }

    context "when the Slack user is not connected to a Cardjoy account" do
      before do
        create(:slack_installation, team_id: team_id)
        stub_slack_users_info(slack_user_id, "New User", email: "newuser@example.com")
        stub_slack_views_open
      end

      it "auto-provisions a user and opens the modal" do
        expect {
          post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")
        }.to change { User.count }.by(1)
          .and change { SlackUserConnection.count }.by(1)

        expect(response).to have_http_status(:ok)
      end

      it "creates the user with Slack profile data" do
        post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")

        user = User.last
        expect(user.email).to eq("newuser@example.com")
        expect(user.name).to eq("New User")
        expect(user.provider).to eq("slack")
        expect(user.email_confirmed).to be true
      end

      it "links the connection to the auto-provisioned user" do
        post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")

        connection = SlackUserConnection.last
        expect(connection.slack_user_id).to eq(slack_user_id)
        expect(connection.slack_team_id).to eq(team_id)
        expect(connection.user).to eq(User.last)
      end

      it "does not create a shadow account when the Slack profile has no email" do
        stub_slack_users_info(slack_user_id, "No Email User")

        expect {
          post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")
        }.to change { User.count }.by(0).and change { SlackUserConnection.count }.by(0)
      end

      it "prompts the user to connect a real account when there is no email" do
        stub_slack_users_info(slack_user_id, "No Email User")

        post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["response_type"]).to eq("ephemeral")
        expect(json["text"]).to include("#{frontend_url}/connect-slack?state=")
      end

      it "links to an existing user when the email matches" do
        existing_user = create(:user, email: "newuser@example.com")

        expect {
          post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")
        }.to change { User.count }.by(0)
          .and change { SlackUserConnection.count }.by(1)

        expect(SlackUserConnection.last.user).to eq(existing_user)
      end
    end

    context "when the workspace has no SlackInstallation" do
      it "returns an ephemeral error message" do
        post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.123")

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["response_type"]).to eq("ephemeral")
        expect(json["text"]).to include("not installed")
      end
    end

    context "when the Slack user is connected to a Cardjoy account" do
      before do
        create(:slack_installation, team_id: team_id)
        create(:slack_user_connection, user: user, slack_user_id: slack_user_id, slack_team_id: team_id)
      end

      it "opens the modal and returns ok" do
        stub_slack_views_open

        post_slash_command(user_id: slack_user_id, team_id: team_id, trigger_id: "trigger.abc")

        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ------------------------------------------------------------------
  # Modal submission
  # ------------------------------------------------------------------

  describe "modal submission (view_submission)" do
    let(:user) { create(:user) }
    let(:team_id) { "T12345" }
    let(:slack_user_id) { "U67890" }
    let(:recipient_slack_id) { "U11111" }

    before do
      create(:slack_installation, team_id: team_id, access_token: "xoxb-test")
      create(:slack_user_connection, user: user, slack_user_id: slack_user_id, slack_team_id: team_id)
    end

    def submission_payload(recipient_id: recipient_slack_id, occasion: "Birthday", response_url: "")
      {
        "type" => "view_submission",
        "user" => { "id" => slack_user_id, "team_id" => team_id },
        "view" => {
          "callback_id" => "create_card",
          "private_metadata" => response_url,
          "state" => {
            "values" => {
              "recipient_block" => {
                "recipient_user" => { "type" => "users_select", "selected_user" => recipient_id }
              },
              "occasion_block" => {
                "occasion_select" => {
                  "type" => "static_select",
                  "selected_option" => { "value" => occasion }
                }
              }
            }
          }
        }
      }
    end

    it "creates a card and returns response_action: clear" do
      stub_slack_users_info(recipient_slack_id, "Mike Smith")

      expect {
        post_modal_submission(submission_payload)
      }.to change { Card.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["response_action"]).to eq("clear")
    end

    it "sets the card title, recipient, and occasion from the modal values" do
      stub_slack_users_info(recipient_slack_id, "Mike Smith")

      post_modal_submission(submission_payload(occasion: "Graduation"))

      card = Card.last
      expect(card.title).to eq("Card for Mike Smith")
      expect(card.recipients).to eq([ "Mike Smith" ])
      expect(card.occasion).to eq("Graduation")
      expect(card.user).to eq(user)
    end

    it "uses a personalized title for Slack occasions" do
      stub_slack_users_info(recipient_slack_id, "Alice")

      post_modal_submission(submission_payload(occasion: "First day at work"))
      expect(Card.last.title).to eq("Welcome to the team, Alice!")

      stub_slack_users_info(recipient_slack_id, "Bob")
      post_modal_submission(submission_payload(occasion: "Promotion at work"))
      expect(Card.last.title).to eq("Congrats on the promotion, Bob!")
    end

    it "posts a follow-up message to the response_url when present" do
      stub_slack_users_info(recipient_slack_id, "Alice")
      response_stub = stub_request(:post, "https://hooks.slack.com/test_response")
        .to_return(status: 200, body: '{"ok":true}')

      post_modal_submission(submission_payload(response_url: "https://hooks.slack.com/test_response"))

      expect(response_stub).to have_been_requested
    end

    it "posts the card URL as a mrkdwn hyperlink with auth token" do
      stub_slack_users_info(recipient_slack_id, "Alice")
      stub_request(:post, "https://hooks.slack.com/test_response")
        .to_return(status: 200, body: '{"ok":true}')

      post_modal_submission(submission_payload(response_url: "https://hooks.slack.com/test_response"))

      expect(a_request(:post, "https://hooks.slack.com/test_response").with { |req|
        body = JSON.parse(req.body)
        body["mrkdwn"] == true &&
          body["text"].include?("|See card>") &&
          body["text"].include?("#{frontend_url}/card/") &&
          body["text"].include?("?token=")
      }).to have_been_made
    end

    it "returns errors response when the Slack user is not connected" do
      post_modal_submission(submission_payload.merge("user" => { "id" => "U_UNKNOWN", "team_id" => team_id }))

      json = JSON.parse(response.body)
      expect(json["response_action"]).to eq("errors")
    end

    it "supports all Slack occasions" do
      SlackWebhooksController::SLACK_OCCASIONS.each do |occasion|
        stub_slack_users_info(recipient_slack_id, "Test User")
        post_modal_submission(submission_payload(occasion: occasion))
        expect(Card.last.occasion).to eq(occasion)
      end
    end

    it "uses the 4 workplace-specific Slack occasions" do
      expect(SlackWebhooksController::SLACK_OCCASIONS).to eq([
        "First day at work",
        "Last day at work",
        "Promotion at work",
        "Work anniversary"
      ])
    end

    context "when a gallery style tagged for the occasion exists" do
      it "attaches the style's image as the card's default cover image" do
        stub_slack_users_info(recipient_slack_id, "Bob")

        tag = create(:tag, name: "first-day-at-work")
        style = create(:style, kind: "cover")
        create(:style_tag, style: style, tag: tag)
        style.image.attach(
          io: File.open(Rails.root.join("spec", "fixtures", "files", "test_image.jpg")),
          filename: "test_image.jpg",
          content_type: "image/jpeg"
        )

        post_modal_submission(submission_payload(occasion: "First day at work"))

        expect(Card.last.cover_image).to be_attached
      end
    end

    context "when no gallery style is tagged for the occasion" do
      it "creates the card without a cover image" do
        stub_slack_users_info(recipient_slack_id, "Bob")

        post_modal_submission(submission_payload(occasion: "First day at work"))

        expect(Card.last.cover_image).not_to be_attached
      end
    end

    describe "credit deduction" do
      it "deducts exactly one credit and records a card_created event" do
        stub_slack_users_info(recipient_slack_id, "Mike Smith")

        expect {
          post_modal_submission(submission_payload)
        }.to change { user.reload.credit_balance }.by(-1)

        debit = user.credits.order(:id).last
        expect(debit.amount).to eq(-1)
        expect(debit.events.first["event_kind"]).to eq("card_created")
      end

      it "blocks the create and charges nothing when the balance is empty" do
        stub_slack_users_info(recipient_slack_id, "Mike Smith")
        user.credits.destroy_all
        card_count = Card.count
        credit_count = Credit.count

        post_modal_submission(submission_payload)

        json = JSON.parse(response.body)
        expect(json["response_action"]).to eq("errors")
        expect(json["errors"].values.join).to include("out of CardJoy credits")
        expect(Card.count).to eq(card_count)
        expect(Credit.count).to eq(credit_count)
      end

      it "does not post a follow-up message when the balance is empty" do
        stub_slack_users_info(recipient_slack_id, "Mike Smith")
        user.credits.destroy_all
        response_stub = stub_request(:post, "https://hooks.slack.com/test_response")
          .to_return(status: 200, body: '{"ok":true}')

        post_modal_submission(submission_payload(response_url: "https://hooks.slack.com/test_response"))

        expect(response_stub).not_to have_been_requested
      end
    end
  end

  # ------------------------------------------------------------------
  # app_uninstalled event
  # ------------------------------------------------------------------

  describe "app_uninstalled event" do
    let(:team_id) { "T99999" }

    before do
      create(:slack_installation, team_id: team_id)
      create_list(:slack_user_connection, 2, slack_team_id: team_id)
    end

    it "destroys the installation and all user connections for the workspace" do
      post_event(type: "event_callback", team_id: team_id, event: { type: "app_uninstalled" })

      expect(response).to have_http_status(:ok)
      expect(SlackInstallation.find_by(team_id: team_id)).to be_nil
      expect(SlackUserConnection.where(slack_team_id: team_id)).to be_empty
    end

    it "does not affect other workspaces" do
      other = create(:slack_installation)
      other_conn = create(:slack_user_connection, slack_team_id: other.team_id)

      post_event(type: "event_callback", team_id: team_id, event: { type: "app_uninstalled" })

      expect(SlackInstallation.find_by(team_id: other.team_id)).to be_present
      expect(SlackUserConnection.find_by(id: other_conn.id)).to be_present
    end
  end

  # ------------------------------------------------------------------
  # tokens_revoked event
  # ------------------------------------------------------------------

  describe "tokens_revoked event" do
    let(:team_id) { "T88888" }

    it "destroys only the specified user connections" do
      revoked = create(:slack_user_connection, slack_team_id: team_id, slack_user_id: "U111")
      kept    = create(:slack_user_connection, slack_team_id: team_id, slack_user_id: "U222")

      post_event(
        type: "event_callback",
        team_id: team_id,
        event: { type: "tokens_revoked", tokens: { oauth: [ "U111" ] } }
      )

      expect(response).to have_http_status(:ok)
      expect(SlackUserConnection.find_by(id: revoked.id)).to be_nil
      expect(SlackUserConnection.find_by(id: kept.id)).to be_present
    end
  end
end
