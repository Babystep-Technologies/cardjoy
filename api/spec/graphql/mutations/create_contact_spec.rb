require "rails_helper"

RSpec.describe Mutations::CreateContact, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateContact($name: String!, $email: String, $relationship: String) {
        createContact(input: { name: $name, email: $email, relationship: $relationship }) {
          contact { id name email relationship }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, token_header: headers)
    post "/graphql", params: { query:, variables: }.to_json, headers: token_header
    JSON.parse(response.body).dig("data", "createContact")
  end

  it "creates a contact scoped to the current user" do
    expect { exec({ name: "Mom", email: "mom@example.com", relationship: "Family" }) }
      .to change { user.contacts.count }.by(1)

    data = JSON.parse(response.body).dig("data", "createContact")
    expect(data["errors"]).to be_empty
    expect(data["contact"]).to include("name" => "Mom", "email" => "mom@example.com", "relationship" => "Family")
  end

  it "returns validation errors for a missing name" do
    data = exec({ name: "" })
    expect(data["contact"]).to be_nil
    expect(data["errors"]).to include("Name can't be blank")
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { name: "Nobody" } }.to_json,
      headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
