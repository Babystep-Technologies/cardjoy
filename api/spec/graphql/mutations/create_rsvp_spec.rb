require "rails_helper"

RSpec.describe Mutations::CreateRsvp, type: :request do
  let(:host_user) { create(:user) }
  let(:invitation) { create(:invitation, user: host_user, max_additional_guests: 2) }

  let(:query) do
    <<~GRAPHQL
      mutation CreateRsvp($input: CreateRsvpInput!) {
        createRsvp(input: $input) {
          rsvp {
            id
            guestName
            guestEmail
            status
            plusOne
            additionalGuestsCount
            plusOneName
            message
          }
          errors
          calendarLinks {
            google
            outlook
            yahoo
            ics
          }
        }
      }
    GRAPHQL
  end

  def execute_rsvp_mutation(variables)
    post "/graphql",
      params: {
        query: query,
        operationName: "CreateRsvp",
        variables: { input: variables }
      }.to_json,
      headers: { "Content-Type" => "application/json" }
  end

  describe "creating a new RSVP" do
    it "creates an RSVP with status going" do
      expect {
        execute_rsvp_mutation(
          invitationId: invitation.id,
          guestName: "John Doe",
          guestEmail: "john@example.com",
          status: "going",
          plusOne: false,
          message: "Can't wait to be there!"
        )
      }.to change(Rsvp, :count).by(1)

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "createRsvp")
      expect(data["errors"]).to be_empty
      expect(data["rsvp"]).to be_present
      expect(data["rsvp"]["guestName"]).to eq("John Doe")
      expect(data["rsvp"]["guestEmail"]).to eq("john@example.com")
      expect(data["rsvp"]["status"]).to eq("going")
      expect(data["rsvp"]["plusOne"]).to be false
      expect(data["rsvp"]["message"]).to eq("Can't wait to be there!")
      expect(data["calendarLinks"]).to be_present
      expect(data["calendarLinks"]["google"]).to be_present
    end

    it "creates an RSVP with status not-going" do
      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "Jane Smith",
        guestEmail: "jane@example.com",
        status: "not-going",
        message: "Sorry, I have another commitment."
      )

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "createRsvp")
      expect(data["errors"]).to be_empty
      expect(data["rsvp"]["status"]).to eq("not-going")
      expect(data["calendarLinks"]).to be_nil
    end

    it "creates an RSVP with status maybe" do
      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "Bob Wilson",
        guestEmail: "bob@example.com",
        status: "maybe"
      )

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "createRsvp")
      expect(data["errors"]).to be_empty
      expect(data["rsvp"]["status"]).to eq("maybe")
    end

    it "creates an RSVP with additional guests" do
      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "Alice Brown",
        guestEmail: "alice@example.com",
        status: "going",
        additionalGuestsCount: 2,
        plusOneName: "Charlie Brown, Dana Smith"
      )

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "createRsvp")
      expect(data["errors"]).to be_empty
      expect(data["rsvp"]["plusOne"]).to be true
      expect(data["rsvp"]["additionalGuestsCount"]).to eq(2)
      expect(data["rsvp"]["plusOneName"]).to eq("Charlie Brown, Dana Smith")
    end

    it "downcases the guest email" do
      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "Test User",
        guestEmail: "TEST@EXAMPLE.COM",
        status: "going"
      )

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["rsvp"]["guestEmail"]).to eq("test@example.com")
    end

    it "accepts invitation external_id as invitationId" do
      execute_rsvp_mutation(
        invitationId: invitation.external_id,
        guestName: "External ID User",
        guestEmail: "external@example.com",
        status: "going"
      )

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "createRsvp")
      expect(data["errors"]).to be_empty
      expect(data["rsvp"]).to be_present
    end
  end

  describe "updating an existing RSVP" do
    let!(:existing_rsvp) do
      create(:rsvp,
        invitation: invitation,
        guest_name: "Original Name",
        guest_email: "update@example.com",
        status: "maybe"
      )
    end

    it "updates RSVP when same email submits again" do
      expect {
        execute_rsvp_mutation(
          invitationId: invitation.id,
          guestName: "Updated Name",
          guestEmail: "update@example.com",
          status: "going",
          message: "Changed my mind, I'm coming!"
        )
      }.not_to change(Rsvp, :count)

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["errors"]).to be_empty
      expect(data["rsvp"]["guestName"]).to eq("Updated Name")
      expect(data["rsvp"]["status"]).to eq("going")
      expect(data["rsvp"]["message"]).to eq("Changed my mind, I'm coming!")

      existing_rsvp.reload
      expect(existing_rsvp.guest_name).to eq("Updated Name")
      expect(existing_rsvp.status).to eq("going")
    end

    it "clears plus_one_name when plus_one is set to false" do
      existing_rsvp.update!(plus_one: true, plus_one_name: "Previous Plus One")

      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "Original Name",
        guestEmail: "update@example.com",
        status: "going",
        plusOne: false
      )

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["rsvp"]["plusOne"]).to be false
      expect(data["rsvp"]["plusOneName"]).to be_nil
    end
  end

  describe "error cases" do
    it "returns error when invitation not found" do
      execute_rsvp_mutation(
        invitationId: "nonexistent-id",
        guestName: "Test User",
        guestEmail: "test@example.com",
        status: "going"
      )

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["rsvp"]).to be_nil
      expect(data["errors"]).to include("Invitation not found")
    end

    it "returns error when RSVP deadline has passed" do
      past_deadline_invitation = create(:invitation,
        user: host_user,
        rsvp_deadline: Date.yesterday
      )

      execute_rsvp_mutation(
        invitationId: past_deadline_invitation.id,
        guestName: "Late User",
        guestEmail: "late@example.com",
        status: "going"
      )

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["rsvp"]).to be_nil
      expect(data["errors"]).to include("RSVP deadline has passed")
    end
  end

  describe "calendar links" do
    it "returns calendar links when status is going" do
      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "Calendar User",
        guestEmail: "calendar@example.com",
        status: "going"
      )

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["calendarLinks"]).to be_present
      expect(data["calendarLinks"]["google"]).to include("calendar.google.com")
      expect(data["calendarLinks"]["outlook"]).to include("outlook.live.com")
      expect(data["calendarLinks"]["yahoo"]).to include("calendar.yahoo.com")
      expect(data["calendarLinks"]["ics"]).to include("BEGIN:VCALENDAR")
    end

    it "does not return calendar links when status is not-going" do
      execute_rsvp_mutation(
        invitationId: invitation.id,
        guestName: "No Calendar User",
        guestEmail: "nocalendar@example.com",
        status: "not-going"
      )

      json = JSON.parse(response.body)
      data = json.dig("data", "createRsvp")
      expect(data["calendarLinks"]).to be_nil
    end
  end

  describe "email notifications" do
    it "sends confirmation email to guest and notification to host" do
      expect {
        execute_rsvp_mutation(
          invitationId: invitation.id,
          guestName: "Email Test User",
          guestEmail: "emailtest@example.com",
          status: "going"
        )
      }.to have_enqueued_mail(RsvpMailer, :guest_confirmation)
        .and have_enqueued_mail(RsvpMailer, :host_notification)
    end
  end
end
