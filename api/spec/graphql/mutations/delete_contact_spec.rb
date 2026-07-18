require "rails_helper"

RSpec.describe Mutations::DeleteContact, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation DeleteContact($contactId: ID!) {
        deleteContact(input: { contactId: $contactId }) { success errors }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "deleteContact")
  end

  it "deletes the caller's contact and its occasions" do
    contact = create(:contact, :with_occasions, user:)
    expect { exec(contactId: contact.id) }
      .to change(Contact, :count).by(-1).and change(Occasion, :count).by(-2)
    expect(response).to have_http_status(:ok)
  end

  it "does not delete another user's contact" do
    other = create(:contact)
    data = exec(contactId: other.id)
    expect(data["success"]).to be false
    expect(data["errors"]).to include("Contact not found or not owned by user")
    expect(Contact.exists?(other.id)).to be true
  end
end
