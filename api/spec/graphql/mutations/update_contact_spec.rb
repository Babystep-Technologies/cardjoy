require "rails_helper"

RSpec.describe Mutations::UpdateContact, type: :request do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, user:, name: "Old Name", relationship: "Friend") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation UpdateContact($contactId: ID!, $name: String, $relationship: String) {
        updateContact(input: { contactId: $contactId, name: $name, relationship: $relationship }) {
          contact { id name relationship }
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

  it "does not update another user's contact" do
    other = create(:contact, name: "Theirs")
    data = exec(contactId: other.id, name: "Hacked")
    expect(data["contact"]).to be_nil
    expect(data["errors"]).to include("Contact not found or not owned by user")
    expect(other.reload.name).to eq("Theirs")
  end
end
