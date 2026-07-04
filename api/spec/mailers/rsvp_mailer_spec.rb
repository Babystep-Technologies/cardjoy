require "rails_helper"

RSpec.describe RsvpMailer, type: :mailer do
  describe "#invitation_updated" do
    let(:user) { create(:user) }
    let(:invitation) do
      create(:invitation,
        user: user,
        title: "Summer Party",
        description: "Pool party at the beach house",
        location: "123 Beach Road",
        event_date: Date.parse("2025-07-15"),
        event_time: "18:00",
        event_timezone: "America/Los_Angeles",
        attire: "Casual swimwear",
        custom_instructions: "Bring your own towel"
      )
    end

    let(:rsvp_going) do
      create(:rsvp,
        invitation: invitation,
        guest_name: "Alice Smith",
        guest_email: "alice@example.com",
        status: "going",
        plus_one: true,
        plus_one_name: "Bob Jones"
      )
    end

    let(:rsvp_maybe) do
      create(:rsvp,
        invitation: invitation,
        guest_name: "Charlie Brown",
        guest_email: "charlie@example.com",
        status: "maybe"
      )
    end

    let(:mail_going) { RsvpMailer.invitation_updated(rsvp_going) }
    let(:mail_maybe) { RsvpMailer.invitation_updated(rsvp_maybe) }

    it "sends email to the RSVP guest email" do
      expect(mail_going.to).to eq([ "alice@example.com" ])
    end

    it "has the correct subject" do
      expect(mail_going.subject).to eq("Summer Party has been updated")
    end

    it "includes the guest name in the email body" do
      expect(mail_going.body.encoded).to match("Hey Alice Smith!")
    end

    it "includes the invitation title" do
      expect(mail_going.body.encoded).to match("Summer Party")
    end

    it "includes updated event details" do
      expect(mail_going.body.encoded).to match("Tuesday, July 15, 2025")
      expect(mail_going.body.encoded).to match("06:00 PM")
      expect(mail_going.body.encoded).to match("123 Beach Road")
      expect(mail_going.body.encoded).to match("America/Los_Angeles")
    end

    it "includes description when present" do
      expect(mail_going.body.encoded).to match("Pool party at the beach house")
    end

    it "includes attire when present" do
      expect(mail_going.body.encoded).to match("Casual swimwear")
    end

    it "includes custom instructions when present" do
      expect(mail_going.body.encoded).to match("Bring your own towel")
    end

    it "includes current RSVP status for going guests" do
      expect(mail_going.body.encoded).to match("Going")
    end

    it "includes plus one info for going guests with plus one" do
      expect(mail_going.body.encoded).to match("Plus one: Bob Jones")
    end

    it "includes current RSVP status for maybe guests" do
      expect(mail_maybe.body.encoded).to match("Maybe")
    end

    it "includes a link to view the invitation" do
      frontend_url = Rails.application.credentials.dig(:frontend_url)
      invitation_url = "#{frontend_url}/invitation/#{invitation.external_id}"
      expect(mail_going.body.encoded).to match(invitation_url)
    end

    it "mentions that changes can be reviewed" do
      expect(mail_going.body.encoded).to match(/updated|changes/i)
    end

    it "allows guests to update their RSVP" do
      expect(mail_going.body.encoded).to match(/update your RSVP/i)
    end
  end
end
