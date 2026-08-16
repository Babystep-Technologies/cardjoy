require "rails_helper"

RSpec.describe "Contact list queries", type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  def exec(query, variables: {}, request_headers: headers, operation_name: nil)
    body = { query:, variables: }
    body[:operationName] = operation_name if operation_name
    post "/graphql", params: body.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  describe "myContactLists" do
    let(:query) do
      <<~GRAPHQL
        query MyContactLists {
          myContactLists { id name contactsCount mailableContactsCount createdAt updatedAt }
        }
      GRAPHQL
    end

    it "returns only the caller's lists, alphabetically" do
      create(:contact_list, user:, name: "Work")
      create(:contact_list, user:, name: "Family")
      create(:contact_list, name: "Someone else's")

      result = exec(query).dig("data", "myContactLists")

      expect(result.map { |l| l["name"] }).to eq([ "Family", "Work" ])
    end

    it "reports both counts without being asked for the contacts" do
      list = create(:contact_list, user:, name: "Family")
      create(:contact_list_membership, contact_list: list, contact: create(:contact, user:))
      create(:contact_list_membership, contact_list: list, contact: create(:contact, :mailable, user:))

      result = exec(query).dig("data", "myContactLists").first

      expect(result).to include("contactsCount" => 2, "mailableContactsCount" => 1)
    end

    it "rejects an unauthenticated caller at the controller" do
      exec(query, request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    end

    it "rejects an unauthenticated caller smuggled into a public operation name" do
      result = exec(
        "query Card { myContactLists { id } }",
        request_headers: anonymous_headers,
        operation_name: "Card"
      )

      expect(result["errors"].map { |e| e["message"] }).to include("Not authenticated")
      expect(result.dig("data", "myContactLists")).to be_nil
    end
  end

  describe "contactList(id:)" do
    let(:query) do
      <<~GRAPHQL
        query ContactList($id: ID!) {
          contactList(id: $id) {
            id name contactsCount mailableContactsCount
            contacts { id name mailable }
          }
        }
      GRAPHQL
    end

    it "returns the caller's own list with its contacts, alphabetically" do
      list = create(:contact_list, user:, name: "Family")
      create(:contact_list_membership, contact_list: list, contact: create(:contact, user:, name: "Zoe"))
      create(:contact_list_membership, contact_list: list, contact: create(:contact, :mailable, user:, name: "Al"))

      result = exec(query, variables: { id: list.id }).dig("data", "contactList")

      expect(result["name"]).to eq("Family")
      expect(result["contacts"].map { |c| c["name"] }).to eq([ "Al", "Zoe" ])
      expect(result["contacts"].map { |c| c["mailable"] }).to eq([ true, false ])
    end

    it "returns an empty contacts array for an empty list" do
      list = create(:contact_list, user:)

      result = exec(query, variables: { id: list.id }).dig("data", "contactList")

      expect(result["contacts"]).to eq([])
      expect(result["contactsCount"]).to eq(0)
    end

    it "returns nil for someone else's list rather than leaking it" do
      other = create(:contact_list, name: "Not yours")

      result = exec(query, variables: { id: other.id })

      expect(result.dig("data", "contactList")).to be_nil
      expect(result["errors"]).to be_nil
    end

    it "returns nil for an id that does not exist" do
      expect(exec(query, variables: { id: "0" }).dig("data", "contactList")).to be_nil
    end

    it "rejects an unauthenticated caller at the controller" do
      list = create(:contact_list, user:)
      exec(query, variables: { id: list.id }, request_headers: anonymous_headers)

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    end

    it "rejects an unauthenticated caller smuggled into a public operation name" do
      list = create(:contact_list, user:)
      result = exec(
        "query Card($id: ID!) { contactList(id: $id) { id } }",
        variables: { id: list.id },
        request_headers: anonymous_headers,
        operation_name: "Card"
      )

      expect(result["errors"].map { |e| e["message"] }).to include("Not authenticated")
      expect(result.dig("data", "contactList")).to be_nil
    end
  end

  describe "myContacts { contactLists }" do
    let(:query) do
      <<~GRAPHQL
        query MyContacts {
          myContacts { id name contactLists { id name } }
        }
      GRAPHQL
    end

    it "shows each contact's list membership inline" do
      contact = create(:contact, user:, name: "Mom")
      create(:contact, user:, name: "Unlisted")
      family = create(:contact_list, user:, name: "Family")
      cards = create(:contact_list, user:, name: "Cards 2026")
      create(:contact_list_membership, contact_list: family, contact:)
      create(:contact_list_membership, contact_list: cards, contact:)

      result = exec(query).dig("data", "myContacts")

      mom = result.find { |c| c["name"] == "Mom" }
      expect(mom["contactLists"].map { |l| l["name"] }).to eq([ "Cards 2026", "Family" ])
      expect(result.find { |c| c["name"] == "Unlisted" }["contactLists"]).to eq([])
    end
  end
end
