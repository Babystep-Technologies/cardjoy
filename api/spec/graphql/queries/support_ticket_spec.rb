require "rails_helper"

RSpec.describe "supportTicket", type: :request do
  let(:user) { create(:user) }
  let(:stranger) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:ticket) { create(:support_ticket, user:) }

  let(:query) do
    <<~GRAPHQL
      query SupportTicket($externalId: String!) {
        supportTicket(externalId: $externalId) { externalId subject }
      }
    GRAPHQL
  end

  def fetch(external_id:, request_headers: headers)
    post "/graphql", params: { query:, variables: { externalId: external_id } }.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  it "returns the caller's own ticket" do
    result = fetch(external_id: ticket.external_id).dig("data", "supportTicket")

    expect(result["externalId"]).to eq(ticket.external_id)
  end

  it "returns the same nil for an unknown id and for someone else's ticket" do
    others_ticket = create(:support_ticket, user: stranger)

    unknown = fetch(external_id: "ZZZZZZZ").dig("data", "supportTicket")
    strangers = fetch(external_id: others_ticket.external_id).dig("data", "supportTicket")

    expect(unknown).to be_nil
    expect(strangers).to be_nil
  end

  it "is rejected outright without a token" do
    fetch(external_id: ticket.external_id, request_headers: anonymous_headers)

    expect(response).to have_http_status(:unauthorized)
  end
end
