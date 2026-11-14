# typed: false

require "rails_helper"

# Host reminder emails to RSVPed guests (#319).
RSpec.describe "sendInvitationReminder", type: :request do
  include ActiveJob::TestHelper

  let(:host) { create(:user) }
  let(:other) { create(:user) }
  let(:invitation) { create(:invitation, user: host, event_date: Date.current + 3.days, event_time: "18:00") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:query) do
    <<~GRAPHQL
      mutation($input: SendInvitationReminderInput!) {
        sendInvitationReminder(input: $input) {
          sentCount
          errors
          invitation { reminderSentAt nextReminderAt }
        }
      }
    GRAPHQL
  end

  def run(input, user: host)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" if user
    post "/graphql", params: { query: query, variables: { input: { externalId: invitation.external_id }.merge(input) } }.to_json,
      headers: headers
    JSON.parse(response.body).dig("data", "sendInvitationReminder")
  end

  before do
    create(:rsvp, invitation: invitation, guest_email: "going@example.com", status: "going")
    create(:rsvp, invitation: invitation, guest_email: "maybe@example.com", status: "maybe")
    create(:rsvp, invitation: invitation, guest_email: "no@example.com", status: "not-going")
  end

  it "emails going and maybe guests by default, never those who declined" do
    result = nil
    expect { result = run({}) }.to have_enqueued_mail(RsvpMailer, :event_reminder).exactly(2).times

    expect(result["errors"]).to eq []
    expect(result["sentCount"]).to eq 2
    expect(result["invitation"]["reminderSentAt"]).to be_present
    expect(result["invitation"]["nextReminderAt"]).to be_present
  end

  it "can target only going guests" do
    expect { run({ audience: "going" }) }.to have_enqueued_mail(RsvpMailer, :event_reminder).once
  end

  it "refuses a second send within a day" do
    run({})

    expect { @again = run({}) }.not_to have_enqueued_mail(RsvpMailer, :event_reminder)
    expect(@again["errors"].first).to match(/already sent today/)
  end

  it "allows another send after the interval" do
    run({})
    invitation.update_columns(reminder_sent_at: 25.hours.ago)

    expect(run({})["sentCount"]).to eq 2
  end

  it "only lets someone who can edit the invitation send" do
    expect(run({}, user: other)["errors"]).to eq [ "Invitation not found" ]
    expect(run({}, user: nil)).to be_nil.or(satisfy { |r| r["errors"].present? })
  end

  it "refuses once the event has passed" do
    invitation.update_columns(event_date: Date.current - 1.day)

    expect(run({})["errors"]).to eq [ "The event has already happened" ]
  end

  it "refuses when nobody is in the chosen audience" do
    invitation.rsvps.where(status: "maybe").destroy_all

    expect(run({ audience: "maybe" })["errors"].first).to match(/No one has RSVPed maybe/)
  end

  it "rejects an unknown audience and an over-long note" do
    expect(run({ audience: "everyone" })["errors"]).to eq [ "Choose who to remind" ]
    expect(run({ note: "x" * 501 })["errors"].first).to match(/under 500/)
  end

  it "hides the reminder timestamps from anyone but the host" do
    run({})
    post "/graphql",
      params: { query: 'query GetInvitation($id: String!) { invitation(externalId: $id) { reminderSentAt nextReminderAt } }',
                variables: { id: invitation.external_id }, operationName: "GetInvitation" }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(JSON.parse(response.body).dig("data", "invitation")).to eq("reminderSentAt" => nil, "nextReminderAt" => nil)
  end
end
