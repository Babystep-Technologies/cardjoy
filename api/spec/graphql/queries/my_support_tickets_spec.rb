require "rails_helper"

RSpec.describe "mySupportTickets", type: :request do
  let(:user) { create(:user) }
  let(:stranger) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:query) do
    <<~GRAPHQL
      query MySupportTickets($page: Int, $perPage: Int, $status: String) {
        mySupportTickets(page: $page, perPage: $perPage, status: $status) {
          supportTickets { externalId status }
          totalCount
          page
          perPage
          totalPages
        }
      }
    GRAPHQL
  end

  def fetch(page: nil, per_page: nil, status: nil, request_headers: headers)
    variables = { page:, perPage: per_page, status: }.compact
    post "/graphql", params: { query:, variables: }.to_json, headers: request_headers
    JSON.parse(response.body)
  end

  it "returns only the caller's own tickets, newest first" do
    older = create(:support_ticket, user:, created_at: 2.days.ago)
    newer = create(:support_ticket, user:, created_at: 1.hour.ago)
    create(:support_ticket, user: stranger)

    result = fetch.dig("data", "mySupportTickets")

    expect(result["supportTickets"].map { |t| t["externalId"] }).to eq([ newer.external_id, older.external_id ])
    expect(result["totalCount"]).to eq(2)
  end

  it "filters by status" do
    create(:support_ticket, user:, status: "open")
    pending = create(:support_ticket, :pending, user:)

    result = fetch(status: "pending").dig("data", "mySupportTickets")

    expect(result["supportTickets"].map { |t| t["externalId"] }).to eq([ pending.external_id ])
  end

  it "rejects an invalid status" do
    result = fetch(status: "bogus")

    expect(result["errors"].first["message"]).to eq("Invalid status")
  end

  it "clamps perPage rather than dividing by zero" do
    create(:support_ticket, user:)

    result = fetch(per_page: 0).dig("data", "mySupportTickets")

    expect(result["perPage"]).to eq(1)
  end

  it "is rejected outright without a token" do
    fetch(request_headers: anonymous_headers)

    expect(response).to have_http_status(:unauthorized)
  end
end
