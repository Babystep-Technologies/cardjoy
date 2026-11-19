# typed: false

require "rails_helper"

# Who can read an invitation's guest list, and who is told they can edit (#321).
RSpec.describe "Invitation host view", type: :request do
  let(:host) { create(:user) }
  let(:stranger) { create(:user) }
  let(:invitation) { create(:invitation, user: host) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:query) do
    <<~GRAPHQL
      query GetInvitation($externalId: String!) {
        invitation(externalId: $externalId) { viewerCanEdit rsvps { guestEmail } }
      }
    GRAPHQL
  end

  before { create(:rsvp, invitation: invitation, guest_email: "guest@example.com") }

  def fetch(claims = nil)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{JWT.encode(claims, secret, 'HS256')}" if claims
    post "/graphql", params: { query: query, operationName: "GetInvitation",
                               variables: { externalId: invitation.external_id } }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "invitation")
  end

  it "gives the host the guest list and edit rights" do
    expect(fetch(user_id: host.id)).to eq("viewerCanEdit" => true, "rsvps" => [ { "guestEmail" => "guest@example.com" } ])
  end

  it "gives a signed-in stranger neither" do
    expect(fetch(user_id: stranger.id)).to eq("viewerCanEdit" => false, "rsvps" => [])
  end

  it "gives an anonymous guest neither" do
    expect(fetch).to eq("viewerCanEdit" => false, "rsvps" => [])
  end

  it "gives a Felicito admin the guest list" do
    expect(fetch(admin_id: create(:admin).id)["rsvps"].size).to eq 1
  end
end
