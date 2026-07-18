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
          occasion { id kind occursOn recurring nextOccurrence contact { id } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
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
