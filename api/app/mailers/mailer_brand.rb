# typed: true

# The visual identity applied to one outgoing email (#123).
#
# Wraps an optional Organization and answers every question the mailer layout
# asks. Each reader falls back to CardJoy's own value, so an unbranded
# organization — and a personal send, which has no organization at all — renders
# exactly what shipped before organizations existed. That property is pinned by
# spec/mailers/mailer_layout_spec.rb against a recorded fixture; treat a diff
# there as a change to every customer-facing email.
#
# Only structured fields live here, never raw customer HTML: these values are
# interpolated into email CSS and headers, and the models that supply them
# (Organization) validate their shape.
class MailerBrand
  extend T::Sig

  ACCENT_COLOR = "#433c69"
  BODY_BACKGROUND = "#fefaf9"
  TEXT_COLOR = "#573b6f"
  LOGO_ALT = "CardJoy Logo"

  sig { params(organization: T.nilable(Organization)).void }
  def initialize(organization: nil)
    @organization = organization
  end

  # Resolved lazily and memoized, because working it out can cost a network
  # round trip — see #cardjoy_logo_url.
  sig { returns(T.nilable(String)) }
  def logo_url
    return @logo_url if defined?(@logo_url)

    @logo_url = T.let(organization_logo_url || cardjoy_logo_url, T.nilable(String))
  end

  sig { returns(String) }
  def logo_alt
    organization_logo_url ? T.must(@organization).name : LOGO_ALT
  end

  sig { returns(String) }
  def accent_color
    @organization&.accent_color.presence || ACCENT_COLOR
  end

  sig { returns(String) }
  def body_background
    BODY_BACKGROUND
  end

  sig { returns(String) }
  def text_color
    TEXT_COLOR
  end

  sig { returns(String) }
  def footer_text
    @organization&.email_footer_text.presence ||
      "© #{Time.now.year} BabyStep Technologies, Inc. All rights reserved."
  end

  # The address a recipient's reply goes to. nil leaves the header off entirely,
  # which is the CardJoy default. `From` is never changed: we don't control a
  # customer's SPF/DKIM records, so sending as their domain would wreck
  # deliverability. See ApplicationMailer#brand_reply_to.
  sig { returns(T.nilable(String)) }
  def reply_to
    @organization&.email_reply_to.presence
  end

  private

  # An attached blob is known to exist, so unlike the global logo this needs no
  # availability check — and must not make one (#123: no HTTP request when
  # rendering an organization logo).
  sig { returns(T.nilable(String)) }
  def organization_logo_url
    return nil unless @organization&.logo&.attached?

    T.must(@organization).logo_url
  end

  # Pre-existing behaviour, deliberately carried over unchanged: the global logo
  # lives on a bucket this app doesn't own, so it is HEADed before being
  # rendered rather than risking a broken image in every email. Reached only
  # when there is no organization logo to use instead.
  sig { returns(T.nilable(String)) }
  def cardjoy_logo_url
    url = Rails.configuration.x.app_logo_for_email
    return nil if url.blank?

    logo_available?(url) ? url : nil
  end

  sig { params(url: String).returns(T::Boolean) }
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
