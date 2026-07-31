require "rails_helper"

RSpec.describe Mutations::UpdateContact, type: :request do
  let(:user) { create(:user) }
  let(:contact) do
    create(:contact, user:, name: "Old Name", relationship: "Friend", phone: "+14155550123", notes: "Old notes")
  end
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation UpdateContact(
        $contactId: ID!, $name: String, $email: String, $relationship: String, $phone: String, $notes: String
      ) {
        updateContact(
          input: {
            contactId: $contactId, name: $name, email: $email,
            relationship: $relationship, phone: $phone, notes: $notes
          }
        ) {
          contact { id name email relationship phone notes }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "updateContact")
  end

  it "updates the caller's contact" do
    data = exec(contactId: contact.id, name: "New Name")
    expect(data["errors"]).to be_empty
    expect(data["contact"]).to include("name" => "New Name", "relationship" => "Friend")
    expect(contact.reload.name).to eq("New Name")
  end

  it "leaves phone and notes alone when they are omitted" do
    data = exec(contactId: contact.id, name: "New Name")
    expect(data["contact"]).to include("phone" => "+14155550123", "notes" => "Old notes")
  end

  it "clears phone and notes when given an explicit empty string" do
    data = exec(contactId: contact.id, phone: "", notes: "")
    expect(data["errors"]).to be_empty
    expect(data["contact"]).to include("phone" => "", "notes" => "")
  end

  it "returns an error rather than a 500 for an invalid phone" do
    data = exec(contactId: contact.id, phone: "555-0123")
    expect(data["contact"]).to be_nil
    expect(data["errors"]).to include("Phone is not a valid phone number")
    expect(contact.reload.phone).to eq("+14155550123")
  end

  it "saves an unchanged email and phone without colliding with itself" do
    contact.update!(email: "mom@example.com")

    data = exec(contactId: contact.id, name: "New Name", email: "mom@example.com", phone: "+14155550123")
    expect(data["errors"]).to be_empty
    expect(data["contact"]).to include("name" => "New Name")
  end

  it "returns an error when the edit duplicates another of the user's contacts" do
    create(:contact, user:, email: "mom@example.com")

    data = exec(contactId: contact.id, email: "mom@example.com")
    expect(data["contact"]).to be_nil
    expect(data["errors"]).to include("Email #{Contact::DUPLICATE_MESSAGE}")
    expect(contact.reload.email).not_to eq("mom@example.com")
  end

  it "does not update another user's contact" do
    other = create(:contact, name: "Theirs")
    data = exec(contactId: other.id, name: "Hacked")
    expect(data["contact"]).to be_nil
    expect(data["errors"]).to include("Contact not found or not owned by user")
    expect(other.reload.name).to eq("Theirs")
  end
end
