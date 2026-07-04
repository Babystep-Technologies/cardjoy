# typed: false
# frozen_string_literal: true

module Mutations
  class CreateRsvp < BaseMutation
    argument :invitation_id, ID, required: true
    argument :guest_name, String, required: true
    argument :guest_email, String, required: true
    argument :status, String, required: true
    argument :plus_one, Boolean, required: false, default_value: false
    argument :additional_guests_count, Integer, required: false, default_value: 0
    argument :plus_one_name, String, required: false
    argument :message, String, required: false

    field :rsvp, Types::RsvpType, null: true
    field :errors, [ String ], null: false
    field :calendar_links, Types::CalendarLinksType, null: true

    def resolve(
      invitation_id:,
      guest_name:,
      guest_email:,
      status:,
      plus_one: false,
      additional_guests_count: 0,
      plus_one_name: nil,
      message: nil
    )
      invitation = Invitation.find_by(id: invitation_id) || Invitation.find_by(external_id: invitation_id)
      return { rsvp: nil, errors: [ "Invitation not found" ], calendar_links: nil } unless invitation

      # Check for RSVP deadline
      if invitation.rsvp_deadline.present? && invitation.rsvp_deadline < Date.today
        return { rsvp: nil, errors: [ "RSVP deadline has passed" ], calendar_links: nil }
      end

      # Get user if logged in, otherwise create a placeholder user record
      user = context[:current_user]

      # If no logged in user, find or create a temporary user by email
      unless user
        user = User.find_or_initialize_by(email: guest_email.downcase)
        if user.new_record?
          user.name = guest_name
          user.password = SecureRandom.hex(16)
          user.save(validate: false) # Skip password confirmation validation for guest users
        end
      end

      # Check if user already RSVPd to this invitation
      existing_rsvp = Rsvp.find_by(invitation: invitation, guest_email: guest_email.downcase)
      if existing_rsvp
        # Update existing RSVP
        existing_rsvp.assign_attributes(
          guest_name: guest_name,
          status: status,
          plus_one: additional_guests_count > 0,
          additional_guests_count: additional_guests_count,
          plus_one_name: additional_guests_count > 0 ? plus_one_name : nil,
          message: message
        )

        if existing_rsvp.save
          send_rsvp_notifications(existing_rsvp, invitation, is_update: true)
          calendar_links = generate_calendar_links(invitation) if status == "going"
          { rsvp: existing_rsvp, errors: [], calendar_links: calendar_links }
        else
          { rsvp: nil, errors: existing_rsvp.errors.full_messages, calendar_links: nil }
        end
      else
        # Create new RSVP
        rsvp = Rsvp.new(
          invitation: invitation,
          user: user,
          guest_name: guest_name,
          guest_email: guest_email.downcase,
          status: status,
          plus_one: additional_guests_count > 0,
          additional_guests_count: additional_guests_count,
          plus_one_name: additional_guests_count > 0 ? plus_one_name : nil,
          message: message
        )

        if rsvp.save
          send_rsvp_notifications(rsvp, invitation, is_update: false)
          calendar_links = generate_calendar_links(invitation) if status == "going"
          { rsvp: rsvp, errors: [], calendar_links: calendar_links }
        else
          { rsvp: nil, errors: rsvp.errors.full_messages, calendar_links: nil }
        end
      end
    rescue StandardError => e
      Rails.logger.error("CreateRsvp error: #{e.message}")
      { rsvp: nil, errors: [ e.message ], calendar_links: nil }
    end

    private

    def send_rsvp_notifications(rsvp, invitation, is_update:)
      # Send confirmation to guest
      RsvpMailer.guest_confirmation(rsvp).deliver_later

      # Send notification to host
      RsvpMailer.host_notification(rsvp, is_update: is_update).deliver_later
    end

    def generate_calendar_links(invitation)
      event_datetime = DateTime.parse("#{invitation.event_date} #{invitation.event_time}")
      # Assume 2 hour event duration
      end_datetime = event_datetime + 2.hours

      start_time = event_datetime.strftime("%Y%m%dT%H%M%S")
      end_time = end_datetime.strftime("%Y%m%dT%H%M%S")

      title = URI.encode_www_form_component(invitation.title)
      description = URI.encode_www_form_component(invitation.description || "")
      location = URI.encode_www_form_component(invitation.location || "")

      # Google Calendar link
      google_link = "https://calendar.google.com/calendar/render?action=TEMPLATE" \
                    "&text=#{title}" \
                    "&dates=#{start_time}/#{end_time}" \
                    "&details=#{description}" \
                    "&location=#{location}"

      # Outlook Web link
      outlook_link = "https://outlook.live.com/calendar/0/deeplink/compose?subject=#{title}" \
                     "&body=#{description}" \
                     "&startdt=#{event_datetime.iso8601}" \
                     "&enddt=#{end_datetime.iso8601}" \
                     "&location=#{location}"

      # Yahoo Calendar link
      yahoo_link = "https://calendar.yahoo.com/?v=60" \
                   "&title=#{title}" \
                   "&st=#{start_time}" \
                   "&et=#{end_time}" \
                   "&desc=#{description}" \
                   "&in_loc=#{location}"

      # ICS file content (for download)
      ics_content = generate_ics_content(invitation, event_datetime, end_datetime)

      OpenStruct.new(
        google: google_link,
        outlook: outlook_link,
        yahoo: yahoo_link,
        ics: ics_content
      )
    end

    def generate_ics_content(invitation, start_time, end_time)
      uid = "#{invitation.external_id}@cardjoy.app"
      dtstamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
      dtstart = start_time.utc.strftime("%Y%m%dT%H%M%SZ")
      dtend = end_time.utc.strftime("%Y%m%dT%H%M%SZ")

      <<~ICS
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//CardJoy//Event//EN
        BEGIN:VEVENT
        UID:#{uid}
        DTSTAMP:#{dtstamp}
        DTSTART:#{dtstart}
        DTEND:#{dtend}
        SUMMARY:#{invitation.title}
        DESCRIPTION:#{invitation.description&.gsub("
", "\n")}
        LOCATION:#{invitation.location}
        END:VEVENT
        END:VCALENDAR
      ICS
    end
  end
end
