require "rails_helper"

RSpec.describe Mutations::RemoveContactsFromList, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:list) { create(:contact_list, user:, name: "Family") }

  let(:query) do
    <<~GRAPHQL
      mutation RemoveContactsFromList($listId: ID!, $contactIds: [ID!]!) {
        removeContactsFromList(input: { listId: $listId, contactIds: $contactIds }) {
          contactList { id contactsCount contacts { id name } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "removeContactsFromList")
  end

  it "removes several contacts in one call and leaves the contacts themselves alone" do
    mom = create(:contact, user:, name: "Mom")
    dad = create(:contact, user:, name: "Dad")
    kept = create(:contact, user:, name: "Kept")
    [ mom, dad, kept ].each { |c| create(:contact_list_membership, contact_list: list, contact: c) }

    data = exec({ listId: list.id, contactIds: [ mom.id, dad.id ] })

    expect(data["errors"]).to be_empty
    expect(data["contactList"]["contacts"].map { |c| c["name"] }).to eq([ "Kept" ])
    expect(Contact.where(id: [ mom.id, dad.id ]).count).to eq(2)
  end

  it "is a no-op for a contact that is not on the list" do
    unlisted = create(:contact, user:)

    expect { exec({ listId: list.id, contactIds: [ unlisted.id ] }) }
      .not_to change(ContactListMembership, :count)

    expect(JSON.parse(response.body).dig("data", "removeContactsFromList", "errors")).to be_empty
  end

  it "is a no-op for an id that does not exist or belongs to someone else" do
    theirs = create(:contact)

    data = exec({ listId: list.id, contactIds: [ theirs.id, "0" ] })

    expect(data["errors"]).to be_empty
    expect(data["contactList"]["contactsCount"]).to eq(0)
  end

  it "accepts an empty batch as a no-op" do
    expect(exec({ listId: list.id, contactIds: [] })["errors"]).to be_empty
  end

  it "leaves the contact on other lists it belongs to" do
    mom = create(:contact, user:, name: "Mom")
    other = create(:contact_list, user:, name: "Cards 2026")
    create(:contact_list_membership, contact_list: list, contact: mom)
    create(:contact_list_membership, contact_list: other, contact: mom)

    exec({ listId: list.id, contactIds: [ mom.id ] })

    expect(other.reload.contacts_count).to eq(1)
  end

  it "refuses another user's list without saying it exists" do
    other_list = create(:contact_list)
    their_contact = create(:contact, user: other_list.user)
    create(:contact_list_membership, contact_list: other_list, contact: their_contact)

    data = exec({ listId: other_list.id, contactIds: [ their_contact.id ] })

    expect(data["contactList"]).to be_nil
    expect(data["errors"]).to eq([ ContactList::NOT_FOUND_ERROR ])
    expect(other_list.reload.contacts_count).to eq(1)
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { listId: list.id, contactIds: [] } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
