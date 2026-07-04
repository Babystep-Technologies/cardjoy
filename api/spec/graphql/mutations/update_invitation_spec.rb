require 'rails_helper'

RSpec.describe Mutations::UpdateInvitation, type: :request do
  include ActionDispatch::TestProcess::FixtureFile

  let(:user) { create(:user) }
  let(:invitation) do
    create(:invitation,
      user: user,
      title: "Old Party",
      description: "Old description",
      location: "Old location",
      event_date: "2025-06-01",
      event_time: "15:00",
      max_additional_guests: 0
    )
  end

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }

  let(:headers) do
    {
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation UpdateInvitation(
        $externalId: String!
        $title: String
        $description: String
        $location: String
        $eventDate: ISO8601Date
        $eventTime: String
        $eventTimezone: String
        $rsvpDeadline: ISO8601Date
        $coverImageUrl: String
        $coverImageFile: Upload
        $maxAdditionalGuests: Int
        $attire: String
        $customInstructions: String
      ) {
        updateInvitation(
          input: {
            externalId: $externalId
            title: $title
            description: $description
            location: $location
            eventDate: $eventDate
            eventTime: $eventTime
            eventTimezone: $eventTimezone
            rsvpDeadline: $rsvpDeadline
            coverImageUrl: $coverImageUrl
            coverImageFile: $coverImageFile
            maxAdditionalGuests: $maxAdditionalGuests
            attire: $attire
            customInstructions: $customInstructions
          }
        ) {
          invitation {
            externalId
            title
            description
            location
            eventDate
            eventTime
            eventTimezone
            rsvpDeadline
            maxAdditionalGuests
            attire
            customInstructions
          }
          errors
        }
      }
    GRAPHQL
  end

  it "updates invitation title, description, and location" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          title: "Updated Party",
          description: "New exciting description",
          location: "456 New Street, Chicago, IL"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["title"]).to eq("Updated Party")
    expect(data["invitation"]["description"]).to eq("New exciting description")
    expect(data["invitation"]["location"]).to eq("456 New Street, Chicago, IL")

    expect(invitation.reload.title).to eq("Updated Party")
    expect(invitation.description).to eq("New exciting description")
    expect(invitation.location).to eq("456 New Street, Chicago, IL")
  end

  it "updates event date and time" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventDate: "2025-12-25",
          eventTime: "18:30"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventDate"]).to eq("2025-12-25")
    expect(data["invitation"]["eventTime"]).to eq("18:30")
    expect(invitation.reload.event_date.to_s).to eq("2025-12-25")
  end

  it "updates special instructions fields" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          maxAdditionalGuests: 2,
          attire: "Black Tie",
          customInstructions: "Valet parking available"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["maxAdditionalGuests"]).to eq(2)
    expect(data["invitation"]["attire"]).to eq("Black Tie")
    expect(data["invitation"]["customInstructions"]).to eq("Valet parking available")

    expect(invitation.reload.max_additional_guests).to eq(2)
    expect(invitation.attire).to eq("Black Tie")
    expect(invitation.custom_instructions).to eq("Valet parking available")
  end

  it "updates RSVP deadline" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          rsvpDeadline: "2025-11-30"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["rsvpDeadline"]).to eq("2025-11-30")
    expect(invitation.reload.rsvp_deadline.to_s).to eq("2025-11-30")
  end

  it "updates the cover image via file upload" do
    file = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")

    post "/graphql",
      params: {
        operations: {
          query: query,
          variables: {
            externalId: invitation.external_id,
            eventTimezone: "America/Chicago",
            coverImageFile: nil
          }
        }.to_json,
        map: { "0" => [ "variables.coverImageFile" ] }.to_json,
        "0" => file
      },
      headers: headers.merge("Content-Type" => "multipart/form-data")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTimezone"]).to eq("America/Chicago")
    expect(invitation.reload.cover_image).to be_attached
    expect(invitation.event_timezone).to eq("America/Chicago")
  end

  it "updates the cover image via remote URL" do
    url = "https://placehold.co/600x400/EEE/31343C.png"
    stub_request(:get, url).to_return(status: 200, body: "\x89PNG", headers: { "Content-Type" => "image/png" })

    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTimezone: "Asia/Tokyo",
          coverImageUrl: url
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTimezone"]).to eq("Asia/Tokyo")
    expect(invitation.reload.cover_image).to be_attached
    expect(invitation.event_timezone).to eq("Asia/Tokyo")
  end

  it "returns error if user is unauthenticated" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          title: "No Access"
        }
      }.to_json,
      headers: { "Content-Type" => "application/json" }

    json = JSON.parse(response.body)
    expect(json["errors"]).to include("Unauthorized")
  end

  it "returns error if invitation does not belong to user" do
    other_user = create(:user)
    other_invitation = create(:invitation, user: other_user)

    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: other_invitation.external_id,
          title: "Hack Attempt"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    data = json.dig("data", "updateInvitation")
    expect(data["invitation"]).to be_nil
    expect(data["errors"]).to include("Invitation not found")
  end

  it "returns error if invitation does not exist" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: "nonexistent-id",
          title: "Not Found"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    data = json.dig("data", "updateInvitation")
    expect(data["invitation"]).to be_nil
    expect(data["errors"]).to include("Invitation not found")
  end

  it "formats event time to military time HH:MM when updating" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTime: "3:45 PM"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("15:45")
    expect(invitation.reload.event_time).to eq("15:45")
  end

  it "accepts event time in HH:MM format when updating" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTime: "22:15"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("22:15")
  end

  it "strips seconds from event time when updating" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTime: "20:30:00"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("20:30")
  end

  it "returns error for invalid time format when updating" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTime: "not a valid time"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    data = json.dig("data", "updateInvitation")
    expect(data["invitation"]).to be_nil
    expect(data["errors"]).to include("Event time must be in HH:MM format (e.g., 14:00)")
  end

  it "updates timezone" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTimezone: "Europe/London"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTimezone"]).to eq("Europe/London")
    expect(invitation.reload.event_timezone).to eq("Europe/London")
  end

  it "updates event time and timezone together" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          externalId: invitation.external_id,
          eventTime: "6:30 PM",
          eventTimezone: "America/Chicago"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "updateInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("18:30")
    expect(data["invitation"]["eventTimezone"]).to eq("America/Chicago")
    expect(invitation.reload.event_time).to eq("18:30")
    expect(invitation.event_timezone).to eq("America/Chicago")
  end

  describe "enqueuing update notifications to RSVPs" do
    let!(:rsvp_going) do
      create(:rsvp,
        invitation: invitation,
        guest_name: "Alice",
        guest_email: "alice@example.com",
        status: "going"
      )
    end

    let!(:rsvp_maybe) do
      create(:rsvp,
        invitation: invitation,
        guest_name: "Bob",
        guest_email: "bob@example.com",
        status: "maybe"
      )
    end

    let!(:rsvp_not_going) do
      create(:rsvp,
        invitation: invitation,
        guest_name: "Charlie",
        guest_email: "charlie@example.com",
        status: "not-going"
      )
    end

    it "enqueues notification job when invitation is updated" do
      expect {
        post "/graphql",
          params: {
            query: query,
            variables: {
              externalId: invitation.external_id,
              title: "Updated Party"
            }
          }.to_json,
          headers: headers.merge("Content-Type" => "application/json")
      }.to have_enqueued_job(NotifyRsvpsOfUpdateJob)
        .with(invitation.id)

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "updateInvitation")
      expect(data["errors"]).to be_empty
    end

    it "enqueues notification job for location updates" do
      expect {
        post "/graphql",
          params: {
            query: query,
            variables: {
              externalId: invitation.external_id,
              location: "New Location"
            }
          }.to_json,
          headers: headers.merge("Content-Type" => "application/json")
      }.to have_enqueued_job(NotifyRsvpsOfUpdateJob)
        .with(invitation.id)

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "updateInvitation")
      expect(data["errors"]).to be_empty
    end

    it "enqueues notification job for any successful update" do
      expect {
        post "/graphql",
          params: {
            query: query,
            variables: {
              externalId: invitation.external_id,
              description: "Completely new description"
            }
          }.to_json,
          headers: headers.merge("Content-Type" => "application/json")
      }.to have_enqueued_job(NotifyRsvpsOfUpdateJob)
        .with(invitation.id)

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "updateInvitation")
      expect(data["errors"]).to be_empty
    end

    it "updates invitation successfully even if the notification job will run later" do
      post "/graphql",
        params: {
          query: query,
          variables: {
            externalId: invitation.external_id,
            title: "Updated Title"
          }
        }.to_json,
        headers: headers.merge("Content-Type" => "application/json")

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil
      data = json.dig("data", "updateInvitation")
      expect(data["errors"]).to be_empty
      expect(data["invitation"]["title"]).to eq("Updated Title")
      expect(invitation.reload.title).to eq("Updated Title")
    end
  end
end
