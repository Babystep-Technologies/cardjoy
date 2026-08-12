# typed: true

# Mail about a specific invitation, branded by whoever owns that invitation —
# the organization for an org-owned invitation, CardJoy for a personal one
# (#123). Both the guest-facing and host-facing mails are branded: a guest sees
# who invited them, and a host sees their own organization.
class RsvpMailer < ApplicationMailer
  def guest_confirmation(rsvp)
    @rsvp = rsvp
    @invitation = rsvp.invitation
    set_organization_brand(@invitation.owning_organization)
    @invitation_url = "#{Rails.application.credentials.dig(:frontend_url)}/invitation/#{@invitation.external_id}"
    @calendar_links = generate_calendar_links(@invitation) if @rsvp.status == "going"

    subject = case @rsvp.status
    when "going"
                "You're going to #{@invitation.title}! 🎉"
    when "maybe"
                "Your RSVP for #{@invitation.title} has been received"
    else
                "Your RSVP for #{@invitation.title} has been received"
    end

    mail(to: @rsvp.guest_email, subject: subject, **brand_reply_to)
  end

  def host_notification(rsvp, is_update: false)
    @rsvp = rsvp
    @invitation = rsvp.invitation
    set_organization_brand(@invitation.owning_organization)
    @is_update = is_update
    @host = @invitation.user
    @invitation_url = "#{Rails.application.credentials.dig(:frontend_url)}/invitation/#{@invitation.external_id}/edit"

    status_text = case @rsvp.status
    when "going" then "is going"
    when "maybe" then "might be going"
    else "can't make it"
    end

    action = is_update ? "updated their RSVP" : "RSVPd"
    subject = "#{@rsvp.guest_name} #{action} - #{status_text} to #{@invitation.title}"

    mail(to: @host.email, subject: subject, **brand_reply_to)
  end

  def invitation_updated(rsvp)
    @rsvp = rsvp
    @invitation = rsvp.invitation
    set_organization_brand(@invitation.owning_organization)
    @invitation_url = "#{Rails.application.credentials.dig(:frontend_url)}/invitation/#{@invitation.external_id}"

    mail(
      to: @rsvp.guest_email,
      subject: "#{@invitation.title} has been updated",
      **brand_reply_to
    )
  end

  private

  def generate_calendar_links(invitation)
    event_datetime = DateTime.parse("#{invitation.event_date} #{invitation.event_time}")
    end_datetime = event_datetime + 2.hours

    start_time = event_datetime.strftime("%Y%m%dT%H%M%S")
    end_time = end_datetime.strftime("%Y%m%dT%H%M%S")

    title = ERB::Util.url_encode(invitation.title)
    description = ERB::Util.url_encode(invitation.description || "")
    location = ERB::Util.url_encode(invitation.location || "")

    OpenStruct.new(
      google: "https://calendar.google.com/calendar/render?action=TEMPLATE&text=#{title}&dates=#{start_time}/#{end_time}&details=#{description}&location=#{location}",
      outlook: "https://outlook.live.com/calendar/0/deeplink/compose?subject=#{title}&body=#{description}&startdt=#{event_datetime.iso8601}&enddt=#{end_datetime.iso8601}&location=#{location}",
      yahoo: "https://calendar.yahoo.com/?v=60&title=#{title}&st=#{start_time}&et=#{end_time}&desc=#{description}&in_loc=#{location}"
    )
  end
end
