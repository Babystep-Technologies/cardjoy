require 'rails_helper'

RSpec.describe "Oauth::Slack", type: :request do
  let(:frontend_url) { "https://app.cardjoy.test" }

  before do
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:slack, :client_id).and_return("test_client_id")
    allow(Rails.application.credentials).to receive(:dig).with(:slack, :client_secret).and_return("test_client_secret")
    allow(Rails.application.credentials).to receive(:dig).with(:frontend_url).and_return(frontend_url)
  end

  def stub_slack_oauth(response_body)
    stub = double("http_response", body: response_body.to_json)
    http = double("http")
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:request).and_return(stub)
  end

  describe "GET /oauth/slack/callback" do
    context "when Slack returns a successful token exchange" do
      before do
        stub_slack_oauth(
          "ok" => true,
          "access_token" => "xoxb-new-token",
          "team" => { "id" => "T_NEW", "name" => "New Workspace" }
        )
      end

      it "creates a new SlackInstallation and redirects to profile" do
        expect {
          get "/oauth/slack/callback", params: { code: "valid_code" }
        }.to change { SlackInstallation.count }.by(1)

        installation = SlackInstallation.last
        expect(installation.team_id).to eq("T_NEW")
        expect(installation.team_name).to eq("New Workspace")
        expect(installation.access_token).to eq("xoxb-new-token")
        expect(response).to redirect_to("#{frontend_url}/profile?slack_install=success")
      end

      it "updates an existing installation for the same workspace" do
        create(:slack_installation, team_id: "T_NEW", access_token: "old_token")

        expect {
          get "/oauth/slack/callback", params: { code: "valid_code" }
        }.not_to change { SlackInstallation.count }

        expect(SlackInstallation.find_by(team_id: "T_NEW").access_token).to eq("xoxb-new-token")
      end
    end

    context "when Slack returns an error" do
      before do
        stub_slack_oauth("ok" => false, "error" => "invalid_code")
      end

      it "does not create an installation and redirects to error" do
        expect {
          get "/oauth/slack/callback", params: { code: "bad_code" }
        }.not_to change { SlackInstallation.count }

        expect(response).to redirect_to("#{frontend_url}?slack_install=error")
      end
    end

    context "when no code param is present" do
      it "redirects to error without calling Slack" do
        expect(Net::HTTP).not_to receive(:new)

        get "/oauth/slack/callback"

        expect(response).to redirect_to("#{frontend_url}?slack_install=error")
      end
    end
  end
end
