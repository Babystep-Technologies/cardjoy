require "rails_helper"

RSpec.describe Mutations::DeleteContactList, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:list) { create(:contact_list, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation DeleteContactList($id: ID!) {
        deleteContactList(input: { id: $id }) { success errors }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "deleteContactList")
  end

  it "deletes the caller's own list" do
    list_id = list.id

    data = exec({ id: list_id })
    expect(data).to include("success" => true, "errors" => [])
    expect(ContactList.exists?(list_id)).to be(false)
  end

  it "removes the memberships and leaves the contacts intact" do
    contact = create(:contact, user:)
    create(:contact_list_membership, contact_list: list, contact:)

    expect { exec({ id: list.id }) }.to change(ContactListMembership, :count).by(-1)
    expect(Contact.exists?(contact.id)).to be(true)
  end

  it "refuses another user's list without saying it exists" do
    other = create(:contact_list)

    data = exec({ id: other.id })
    expect(data).to include("success" => false)
    expect(data["errors"]).to eq([ ContactList::NOT_FOUND_ERROR ])
    expect(ContactList.exists?(other.id)).to be(true)
  end

  it "gives the same answer for an id that does not exist" do
    expect(exec({ id: "0" })["errors"]).to eq([ ContactList::NOT_FOUND_ERROR ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { id: list.id } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
