# typed: true

module Oauth
  class SlackController < ApplicationController
    skip_before_action :verify_authenticity_token

    def callback
      code = params[:code]

      unless code.present?
        redirect_to "#{frontend_url}?slack_install=error", allow_other_host: true and return
      end

      response = exchange_code_for_token(code)

      unless response["ok"]
        Rails.logger.error("[SlackOAuth] Token exchange failed: #{response['error']}")
        redirect_to "#{frontend_url}?slack_install=error", allow_other_host: true and return
      end

      SlackInstallation.find_or_initialize_by(team_id: response["team"]["id"]).tap do |installation|
        installation.team_name = response["team"]["name"]
        installation.access_token = response["access_token"]
        installation.save!
      end

      redirect_to "#{frontend_url}/profile?slack_install=success", allow_other_host: true
    end

    private

    def exchange_code_for_token(code)
      uri = URI("https://slack.com/api/oauth.v2.access")
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(
        code: code,
        client_id: Rails.application.credentials.dig(:slack, :client_id),
        client_secret: Rails.application.credentials.dig(:slack, :client_secret)
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      res = http.request(req)
      JSON.parse(res.body)
    end

    def frontend_url
      Rails.application.credentials.dig(:frontend_url)
    end
  end
end
