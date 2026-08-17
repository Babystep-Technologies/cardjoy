require "rails_helper"

RSpec.describe Mutations::CreateContactList, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateContactList($name: String!) {
        createContactList(input: { name: $name }) {
          contactList { id name contactsCount mailableContactsCount }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "createContactList")
  end

  it "creates a list scoped to the current user" do
    expect { exec({ name: "Family" }) }.to change { user.contact_lists.count }.by(1)

    data = JSON.parse(response.body).dig("data", "createContactList")
    expect(data["errors"]).to be_empty
    expect(data["contactList"]).to include("name" => "Family", "contactsCount" => 0, "mailableContactsCount" => 0)
  end

  it "rejects a duplicate name for the same user" do
    create(:contact_list, user:, name: "Family")

    data = exec({ name: "Family" })
    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to include("Name #{ContactList::DUPLICATE_NAME_MESSAGE}")
  end

  it "lets a different user use a name this user already has" do
    create(:contact_list, name: "Family")

    data = exec({ name: "Family" })
    expect(data["errors"]).to be_empty
  end

  it "returns a validation error for a blank name" do
    data = exec({ name: "  " })
    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to include("Name can't be blank")
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { name: "Family" } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end

  # PUBLIC_OPERATIONS is matched on the operation *name*, so the resolver has to
  # answer for itself rather than trusting the controller gate.
  it "returns Not authenticated when smuggled into a public operation name" do
    smuggled = <<~GRAPHQL
      mutation UpsertMessage {
        createContactList(input: { name: "Family" }) { contactList { id } errors }
      }
    GRAPHQL

    expect {
      post "/graphql",
        params: { query: smuggled, operationName: "UpsertMessage" }.to_json,
        headers: { "Content-Type" => "application/json" }
    }.not_to change(ContactList, :count)

    data = JSON.parse(response.body).dig("data", "createContactList")
    expect(data["errors"]).to eq([ "Not authenticated" ])
  end
end
