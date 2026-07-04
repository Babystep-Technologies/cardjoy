# typed: true

require "net/http"
require "uri"

class ApplicationMailer < ActionMailer::Base
  default from: "CardJoy <team.cardjoy@gmail.com>"
  layout "mailer"

  before_action :set_brand_logo

  private

  def set_brand_logo
    @logo_url = Rails.application.config.x.app_logo_for_email
    @logo_available = logo_available?(@logo_url)
  end

  def logo_available?(url)
    uri = URI.parse(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.head(uri.path)
    end
    response.is_a?(Net::HTTPSuccess)
  rescue
    false
  end
end
