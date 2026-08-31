require "rails_helper"

RSpec.describe Mutations::VerifyContactAddress, type: :request do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, :mailable, user:) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation VerifyContactAddress($contactId: ID!) {
        verifyContactAddress(input: { contactId: $contactId }) {
          contact {
            id
            addressLine1
            addressVerificationStatus
            addressZone
            addressVerifiedAt
          }
          suggestion {
            addressLine1
            addressLine2
            city
            region
            postalCode
            countryCode
            differsFromContact
          }
          errors
        }
      }
    GRAPHQL
  end

  def run_verify(variables, request_headers: headers)
    post "/graphql", params: { query:, variables: }.to_json, headers: request_headers
    JSON.parse(response.body).dig("data", "verifyContactAddress")
  end

  before { with_post_grid_key }

  describe "a deliverable address" do
    before { stub_verification(body: post_grid_fixture("verification_us_deliverable")) }

    it "persists the verdict, the zone, and the timestamp" do
      data = run_verify({ contactId: contact.id })

      expect(data["errors"]).to be_empty
      expect(data["contact"]).to include(
        "addressVerificationStatus" => "verified",
        "addressZone" => "us_domestic"
      )
      expect(data["contact"]["addressVerifiedAt"]).to be_present

      expect(contact.reload).to have_attributes(
        address_verification_status: "verified",
        address_zone: "us_domestic"
      )
      expect(contact.address_verified_at).to be_present
    end

    # The whole point of returning a suggestion instead of applying one.
    it "returns PostGrid's canonical form without applying it" do
      data = run_verify({ contactId: contact.id })

      expect(data["suggestion"]).to include(
        "addressLine1" => "123 MARKET ST",
        "city" => "SAN FRANCISCO",
        "postalCode" => "94103-1741",
        "countryCode" => "US",
        "differsFromContact" => true
      )
      # The user typed this. It is still what's stored.
      expect(contact.reload.address_line1).to eq("123 Market St")
      expect(data["contact"]["addressLine1"]).to eq("123 Market St")
    end
  end

  describe "an undeliverable address" do
    before { stub_verification(body: post_grid_fixture("verification_us_undeliverable")) }

    it "records undeliverable, keeps the zone, and offers no suggestion" do
      data = run_verify({ contactId: contact.id })

      expect(data["errors"]).to be_empty
      expect(data["contact"]).to include(
        "addressVerificationStatus" => "undeliverable",
        "addressZone" => "us_domestic"
      )
      expect(data["suggestion"]).to be_nil
    end
  end

  describe "authorization" do
    it "is challenged at the controller gate with no token" do
      run_verify({ contactId: contact.id }, request_headers: { "Content-Type" => "application/json" })

      # VerifyContactAddress is not a public operation, so it never reaches the
      # resolver's own "Not authenticated" check.
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["errors"]).to include("Unauthorized")
      expect(contact.reload.address_verification_status).to be_nil
    end

    # PUBLIC_OPERATIONS is matched on the operation *name*, so the resolver has
    # to answer for itself rather than trusting the controller gate.
    it "returns Not authenticated when smuggled into a public operation name" do
      smuggled = <<~GRAPHQL
        mutation UpsertMessage {
          verifyContactAddress(input: { contactId: "#{contact.id}" }) { contact { id } errors }
        }
      GRAPHQL

      post "/graphql",
           params: { query: smuggled, operationName: "UpsertMessage" }.to_json,
           headers: { "Content-Type" => "application/json" }

      data = JSON.parse(response.body).dig("data", "verifyContactAddress")
      expect(data["errors"]).to eq([ "Not authenticated" ])
      expect(contact.reload.address_verification_status).to be_nil
    end

    it "returns Not authorized for another user's contact" do
      other = create(:contact, :mailable, user: create(:user))

      data = run_verify({ contactId: other.id })

      expect(data["contact"]).to be_nil
      expect(data["errors"]).to eq([ "Not authorized" ])
      expect(other.reload.address_verification_status).to be_nil
    end

    # Not-found reads the same as not-yours, so a stranger can't probe which
    # contact ids exist.
    it "returns Not authorized for an unknown contact" do
      expect(run_verify({ contactId: "0" })["errors"]).to eq([ "Not authorized" ])
    end

    it "makes no PostGrid call when the caller is not authorized" do
      stub_verification(body: post_grid_fixture("verification_us_deliverable"))
      other = create(:contact, :mailable, user: create(:user))

      run_verify({ contactId: other.id })

      expect(a_request(:post, PostGridHelpers::VERIFY_URL)).not_to have_been_made
    end
  end

  describe "degradation" do
    it "reports unavailable rather than raising when PostGrid has no key" do
      with_post_grid_key(test_key: nil)
      stub_post_grid_credential(:test_api_key, nil)

      data = run_verify({ contactId: contact.id })

      expect(response).to have_http_status(:ok)
      expect(data["errors"]).to eq([ "Address verification is unavailable" ])
    end

    it "reports unavailable when PostGrid is down" do
      stub_verification(status: 500, body: post_grid_fixture("error_server"))

      data = run_verify({ contactId: contact.id })

      expect(data["errors"]).to eq([ "Address verification is unavailable" ])
      expect(contact.reload.address_verification_status).to be_nil
    end

    it "does not leak PostGrid's message, which can quote the address back" do
      stub_verification(status: 400, body: post_grid_fixture("error_invalid_request"))

      expect(run_verify({ contactId: contact.id })["errors"]).to eq([ "Address verification is unavailable" ])
    end

    it "refuses a contact with no complete address without calling PostGrid" do
      addressless = create(:contact, user:)

      data = run_verify({ contactId: addressless.id })

      expect(data["errors"]).to eq([ "Contact does not have a complete mailing address" ])
      expect(a_request(:post, PostGridHelpers::VERIFY_URL)).not_to have_been_made
    end
  end

  describe "invalidation on edit" do
    let(:update_query) do
      <<~GRAPHQL
        mutation UpdateContact($contactId: ID!, $addressLine1: String, $name: String) {
          updateContact(input: { contactId: $contactId, addressLine1: $addressLine1, name: $name }) {
            contact { id addressVerificationStatus addressZone addressVerifiedAt }
            errors
          }
        }
      GRAPHQL
    end

    def update(variables)
      post "/graphql", params: { query: update_query, variables: }.to_json, headers: headers
      JSON.parse(response.body).dig("data", "updateContact")
    end

    before do
      stub_verification(body: post_grid_fixture("verification_us_deliverable"))
      run_verify({ contactId: contact.id })
      expect(contact.reload.address_verification_status).to eq("verified")
    end

    it "clears all three columns when updateContact changes an address field" do
      data = update(contactId: contact.id, addressLine1: "456 Mission St")

      expect(data["errors"]).to be_empty
      expect(data["contact"]).to include(
        "addressVerificationStatus" => "unverified",
        "addressZone" => nil,
        "addressVerifiedAt" => nil
      )
      expect(contact.reload).to have_attributes(
        address_verification_status: nil, address_zone: nil, address_verified_at: nil
      )
    end

    it "keeps the verdict when a non-address field changes" do
      data = update(contactId: contact.id, name: "New Name")

      expect(data["contact"]).to include("addressVerificationStatus" => "verified")
      expect(contact.reload.address_verification_status).to eq("verified")
    end
  end
end
