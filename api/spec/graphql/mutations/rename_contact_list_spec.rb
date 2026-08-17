require "rails_helper"

RSpec.describe Mutations::RenameContactList, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:list) { create(:contact_list, user:, name: "Family") }

  let(:query) do
    <<~GRAPHQL
      mutation RenameContactList($id: ID!, $name: String!) {
        renameContactList(input: { id: $id, name: $name }) {
          contactList { id name }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "renameContactList")
  end

  it "renames the caller's own list" do
    data = exec({ id: list.id, name: "Cards 2026" })

    expect(data["errors"]).to be_empty
    expect(data["contactList"]["name"]).to eq("Cards 2026")
    expect(list.reload.name).to eq("Cards 2026")
  end

  it "rejects a name another of the caller's lists already uses" do
    create(:contact_list, user:, name: "Work")

    data = exec({ id: list.id, name: "Work" })
    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to include("Name #{ContactList::DUPLICATE_NAME_MESSAGE}")
    expect(list.reload.name).to eq("Family")
  end

  it "returns a validation error for a blank name" do
    data = exec({ id: list.id, name: "" })
    expect(data["errors"]).to include("Name can't be blank")
  end

  it "refuses another user's list without saying it exists" do
    other = create(:contact_list, name: "Not yours")

    data = exec({ id: other.id, name: "Mine now" })
    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to eq([ ContactList::NOT_FOUND_ERROR ])
    expect(other.reload.name).to eq("Not yours")
  end

  it "gives the same answer for an id that does not exist" do
    expect(exec({ id: "0", name: "Whatever" })["errors"]).to eq([ ContactList::NOT_FOUND_ERROR ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { id: list.id, name: "Nope" } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
