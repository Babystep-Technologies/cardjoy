# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::UpdateSupportTicketStatus, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:owner) { create(:user) }
  let(:ticket) { create(:support_ticket, user: owner) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation UpdateSupportTicketStatus($ticketExternalId: String!, $status: String!) {
        updateSupportTicketStatus(input: { ticketExternalId: $ticketExternalId, status: $status }) {
          supportTicket { status statusUpdatedBy { id } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(ticket_external_id: ticket.external_id, status: "closed", token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { ticketExternalId: ticket_external_id, status: status } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "updates the status" do
    payload = exec(status: "closed").dig("data", "updateSupportTicketStatus")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("supportTicket", "status")).to eq "closed"
  end

  it "records which admin acted" do
    payload = exec(status: "closed").dig("data", "updateSupportTicketStatus")

    expect(payload.dig("supportTicket", "statusUpdatedBy", "id")).to eq admin.id.to_s
    expect(ticket.reload.status_updated_by_admin).to eq admin
  end

  it "rejects an invalid status" do
    payload = exec(status: "sideways").dig("data", "updateSupportTicketStatus")

    expect(payload["errors"]).to eq [ "Invalid status" ]
    expect(ticket.reload.status).to eq "open"
  end

  it "reports an unknown ticket as not found" do
    payload = exec(ticket_external_id: "NOTREAL").dig("data", "updateSupportTicketStatus")

    expect(payload["errors"]).to eq [ "Support ticket not found" ]
  end

  it "refuses a customer JWT" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(ticket.reload.status).to eq "open"
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
