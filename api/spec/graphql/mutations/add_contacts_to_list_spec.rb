require "rails_helper"

RSpec.describe Mutations::AddContactsToList, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:list) { create(:contact_list, user:, name: "Family") }

  let(:query) do
    <<~GRAPHQL
      mutation AddContactsToList($listId: ID!, $contactIds: [ID!]!) {
        addContactsToList(input: { listId: $listId, contactIds: $contactIds }) {
          contactList { id name contactsCount mailableContactsCount contacts { id name } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "addContactsToList")
  end

  it "adds several contacts in one call" do
    mom = create(:contact, user:, name: "Mom")
    dad = create(:contact, :mailable, user:, name: "Dad")

    data = exec({ listId: list.id, contactIds: [ mom.id, dad.id ] })

    expect(data["errors"]).to be_empty
    expect(data["contactList"]["contacts"].map { |c| c["name"] }).to eq([ "Dad", "Mom" ])
    expect(data["contactList"]).to include("contactsCount" => 2, "mailableContactsCount" => 1)
  end

  it "is idempotent: adding a contact already on the list is a no-op, not an error" do
    mom = create(:contact, user:, name: "Mom")
    create(:contact_list_membership, contact_list: list, contact: mom)

    expect { exec({ listId: list.id, contactIds: [ mom.id ] }) }.not_to change(ContactListMembership, :count)

    data = JSON.parse(response.body).dig("data", "addContactsToList")
    expect(data["errors"]).to be_empty
    expect(data["contactList"]["contactsCount"]).to eq(1)
  end

  it "adds only the missing ones when the batch overlaps what is already there" do
    mom = create(:contact, user:, name: "Mom")
    dad = create(:contact, user:, name: "Dad")
    create(:contact_list_membership, contact_list: list, contact: mom)

    expect { exec({ listId: list.id, contactIds: [ mom.id, dad.id ] }) }
      .to change(ContactListMembership, :count).by(1)

    expect(list.reload.contacts_count).to eq(2)
  end

  it "collapses duplicate ids within one batch" do
    mom = create(:contact, user:, name: "Mom")

    expect { exec({ listId: list.id, contactIds: [ mom.id, mom.id ] }) }
      .to change(ContactListMembership, :count).by(1)

    expect(JSON.parse(response.body).dig("data", "addContactsToList", "errors")).to be_empty
  end

  it "accepts an empty batch as a no-op" do
    data = exec({ listId: list.id, contactIds: [] })

    expect(data["errors"]).to be_empty
    expect(data["contactList"]["contactsCount"]).to eq(0)
  end

  it "refuses a contact belonging to another user" do
    theirs = create(:contact, name: "Not yours")

    data = exec({ listId: list.id, contactIds: [ theirs.id ] })

    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
    expect(list.reload.contacts_count).to eq(0)
  end

  # All-or-nothing: a partially applied batch would both leak which ids exist
  # and leave the client's view of the list out of sync with what it asked for.
  it "adds nothing when the batch mixes the caller's contacts with someone else's" do
    mine = create(:contact, user:, name: "Mom")
    theirs = create(:contact, name: "Not yours")

    expect { exec({ listId: list.id, contactIds: [ mine.id, theirs.id ] }) }
      .not_to change(ContactListMembership, :count)

    data = JSON.parse(response.body).dig("data", "addContactsToList")
    expect(data["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
    expect(list.reload.contacts_count).to eq(0)
  end

  it "gives the same answer for a contact id that does not exist" do
    data = exec({ listId: list.id, contactIds: [ "0" ] })

    expect(data["errors"]).to eq([ Mutations::BaseMutation::NOT_AUTHORIZED_ERROR ])
  end

  it "refuses another user's list without saying it exists" do
    other_list = create(:contact_list)
    mine = create(:contact, user:)

    data = exec({ listId: other_list.id, contactIds: [ mine.id ] })

    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to eq([ ContactList::NOT_FOUND_ERROR ])
    expect(other_list.reload.contacts_count).to eq(0)
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { listId: list.id, contactIds: [] } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
