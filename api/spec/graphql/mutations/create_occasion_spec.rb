require "rails_helper"

RSpec.describe Mutations::CreateOccasion, type: :request do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, user:) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateOccasion($contactId: ID!, $kind: String!, $occursOn: ISO8601Date!, $recurring: Boolean) {
        createOccasion(input: { contactId: $contactId, kind: $kind, occursOn: $occursOn, recurring: $recurring }) {
          occasion { id kind occursOn recurring nextOccurrence reminderLeadDays contact { id } }
          errors
        }
      }
    GRAPHQL
  end

  # Separate document so the reminder argument can be omitted entirely — an
  # omitted argument and an explicit null mean different things here.
  let(:reminder_query) do
    <<~GRAPHQL
      mutation CreateOccasion($contactId: ID!, $kind: String!, $occursOn: ISO8601Date!, $reminderLeadDays: Int) {
        createOccasion(input: { contactId: $contactId, kind: $kind, occursOn: $occursOn, reminderLeadDays: $reminderLeadDays }) {
          occasion { id reminderLeadDays }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "createOccasion")
  end

  def exec_reminder(variables)
    post "/graphql", params: { query: reminder_query, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "createOccasion")
  end

  it "creates an occasion under the caller's contact" do
    expect { exec(contactId: contact.id, kind: "Birthday", occursOn: "1990-06-15") }
      .to change { contact.occasions.count }.by(1)

    data = JSON.parse(response.body).dig("data", "createOccasion")
    expect(data["errors"]).to be_empty
    expect(data["occasion"]).to include("kind" => "Birthday", "occursOn" => "1990-06-15", "recurring" => true)
    expect(data["occasion"]["nextOccurrence"]).to be_present
  end

  it "defaults the reminder to a week before when none is given" do
    data = exec_reminder(contactId: contact.id, kind: "Birthday", occursOn: "1990-06-15")
    expect(data["errors"]).to be_empty
    expect(data["occasion"]["reminderLeadDays"]).to eq(7)
  end

  it "accepts a chosen reminder lead time" do
    data = exec_reminder(contactId: contact.id, kind: "Birthday", occursOn: "1990-06-15",
      reminderLeadDays: 14)
    expect(data["errors"]).to be_empty
    expect(data["occasion"]["reminderLeadDays"]).to eq(14)
  end

  it "creates with reminders off when the lead time is explicitly null" do
    data = exec_reminder(contactId: contact.id, kind: "Birthday", occursOn: "1990-06-15",
      reminderLeadDays: nil)
    expect(data["errors"]).to be_empty
    expect(data["occasion"]["reminderLeadDays"]).to be_nil
  end

  it "rejects a lead time that is not one of the offered options" do
    data = exec_reminder(contactId: contact.id, kind: "Birthday", occursOn: "1990-06-15",
      reminderLeadDays: 5)
    expect(data["occasion"]).to be_nil
    expect(data["errors"]).to include("Reminder lead days is not included in the list")
  end

  it "rejects an unknown occasion kind" do
    data = exec(contactId: contact.id, kind: "Nope", occursOn: "1990-06-15")
    expect(data["occasion"]).to be_nil
    expect(data["errors"]).to include("Kind is not included in the list")
  end

  it "will not attach an occasion to another user's contact" do
    other = create(:contact)
    data = exec(contactId: other.id, kind: "Birthday", occursOn: "1990-06-15")
    expect(data["occasion"]).to be_nil
    expect(data["errors"]).to include("Contact not found or not owned by user")
  end
end
