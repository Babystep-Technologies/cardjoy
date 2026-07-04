require "rails_helper"

RSpec.describe Mutations::CreateInvitation, type: :request do
  include ActionDispatch::TestProcess::FixtureFile

  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) do
    {
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation CreateInvitation(
        $title: String!
        $description: String
        $location: String
        $eventDate: ISO8601Date!
        $eventTime: String!
        $eventTimezone: String
        $rsvpDeadline: ISO8601Date
        $coverImageUrl: String
        $coverImageFile: Upload
        $maxAdditionalGuests: Int
        $attire: String
        $customInstructions: String
      ) {
        createInvitation(
          input: {
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
            id
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

  it "creates an invitation with all fields" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Summer Pool Party",
          description: "Join us for a splashing good time!",
          location: "123 Beach Lane, Chicago, IL",
          eventDate: "2025-07-15",
          eventTime: "14:00",
          eventTimezone: "America/Los_Angeles",
          rsvpDeadline: "2025-07-10",
          maxAdditionalGuests: 2,
          attire: "Swimwear & Beach Casual",
          customInstructions: "Pool will be heated! Feel free to bring floaties."
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]).to be_present
    expect(data["invitation"]["title"]).to eq("Summer Pool Party")
    expect(data["invitation"]["description"]).to eq("Join us for a splashing good time!")
    expect(data["invitation"]["location"]).to eq("123 Beach Lane, Chicago, IL")
    expect(data["invitation"]["eventDate"]).to eq("2025-07-15")
    expect(data["invitation"]["eventTime"]).to eq("14:00")
    expect(data["invitation"]["eventTimezone"]).to eq("America/Los_Angeles")
    expect(data["invitation"]["rsvpDeadline"]).to eq("2025-07-10")
    expect(data["invitation"]["maxAdditionalGuests"]).to eq(2)
    expect(data["invitation"]["attire"]).to eq("Swimwear & Beach Casual")
    expect(data["invitation"]["customInstructions"]).to eq("Pool will be heated! Feel free to bring floaties.")
    expect(Invitation.last.user).to eq(user)
  end

  it "creates an invitation with minimal required fields" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Quick Event",
          eventDate: "2025-08-01",
          eventTime: "18:00"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]).to be_present
    expect(data["invitation"]["title"]).to eq("Quick Event")
    expect(data["invitation"]["description"]).to be_nil
    expect(data["invitation"]["maxAdditionalGuests"]).to eq(0)
  end

  it "creates an invitation with a cover image file" do
    file = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")

    post "/graphql",
      params: {
        operations: {
          query: query,
          variables: {
            title: "Party with Photo",
            eventDate: "2025-09-01",
            eventTime: "19:00",
            eventTimezone: "America/Los_Angeles",
            coverImageFile: nil # placeholder for map
          }
        }.to_json,
        map: { "0" => [ "variables.coverImageFile" ] }.to_json,
        "0" => file
      },
      headers: headers.merge("Content-Type" => "multipart/form-data")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]).to be_present
    expect(data["invitation"]["eventTimezone"]).to eq("America/Los_Angeles")
    expect(Invitation.last.cover_image).to be_attached
    expect(Invitation.last.event_timezone).to eq("America/Los_Angeles")
  end

  it "creates an invitation with a cover image URL" do
    url = "https://placehold.co/600x400/EEE/31343C.png"
    stub_request(:get, url).to_return(status: 200, body: "\x89PNG", headers: { "Content-Type" => "image/png" })

    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Party with URL",
          eventDate: "2025-09-15",
          eventTime: "20:00",
          eventTimezone: "Europe/London",
          coverImageUrl: url
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]).to be_present
    expect(data["invitation"]["eventTimezone"]).to eq("Europe/London")
    expect(Invitation.last.cover_image).to be_attached
    expect(Invitation.last.event_timezone).to eq("Europe/London")
  end

  it "returns error if user is not authenticated" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Unauthorized Event",
          eventDate: "2025-10-01",
          eventTime: "12:00"
        }
      }.to_json,
      headers: { "Content-Type" => "application/json" }

    json = JSON.parse(response.body)
    expect(json["errors"]).to include("Unauthorized")
  end

  it "returns error if required fields are missing" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Incomplete Event"
          # missing eventDate and eventTime
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_present
  end

  it "formats event time to military time HH:MM" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Time Format Test",
          eventDate: "2025-10-01",
          eventTime: "2:30 PM"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("14:30")
    expect(Invitation.last.event_time).to eq("14:30")
  end

  it "accepts event time in HH:MM format" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Military Time Test",
          eventDate: "2025-10-01",
          eventTime: "18:45"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("18:45")
  end

  it "strips seconds from event time" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Seconds Strip Test",
          eventDate: "2025-10-01",
          eventTime: "14:30:45"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("14:30")
  end

  it "returns error for invalid time format" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Invalid Time",
          eventDate: "2025-10-01",
          eventTime: "invalid time"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    data = json.dig("data", "createInvitation")
    expect(data["invitation"]).to be_nil
    expect(data["errors"]).to include("Event time must be in HH:MM format (e.g., 14:00)")
  end

  it "creates an invitation with timezone" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "Timezone Test",
          eventDate: "2025-10-01",
          eventTime: "3:30 PM",
          eventTimezone: "America/New_York"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("15:30")
    expect(data["invitation"]["eventTimezone"]).to eq("America/New_York")
    expect(Invitation.last.event_timezone).to eq("America/New_York")
  end

  it "creates an invitation without timezone (optional)" do
    post "/graphql",
      params: {
        query: query,
        variables: {
          title: "No Timezone Test",
          eventDate: "2025-10-01",
          eventTime: "14:00"
        }
      }.to_json,
      headers: headers.merge("Content-Type" => "application/json")

    json = JSON.parse(response.body)
    expect(json["errors"]).to be_nil
    data = json.dig("data", "createInvitation")
    expect(data["errors"]).to be_empty
    expect(data["invitation"]["eventTime"]).to eq("14:00")
    expect(data["invitation"]["eventTimezone"]).to be_nil
  end
end
