# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::AssignSupportTicket, type: :request do
  let(:admin) { create(:admin) }
  let(:assignee) { create(:admin) }
  let(:user) { create(:user) }
  let(:owner) { create(:user) }
  let(:ticket) { create(:support_ticket, user: owner) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation AssignSupportTicket($ticketExternalId: String!, $adminId: ID!) {
        assignSupportTicket(input: { ticketExternalId: $ticketExternalId, adminId: $adminId }) {
          supportTicket { assignedAdmin { id name } }
          errors
        }
      }
    GRAPHQL
  end

  def exec(ticket_external_id: ticket.external_id, admin_id: assignee.id, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { ticketExternalId: ticket_external_id, adminId: admin_id } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "assigns the ticket to the given admin" do
    payload = exec.dig("data", "assignSupportTicket")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("supportTicket", "assignedAdmin", "id")).to eq assignee.id.to_s
    expect(ticket.reload.assigned_admin).to eq assignee
  end

  it "reports an unknown ticket as not found" do
    payload = exec(ticket_external_id: "NOTREAL").dig("data", "assignSupportTicket")

    expect(payload["errors"]).to eq [ "Support ticket not found" ]
  end

  it "reports an unknown admin id as not found" do
    payload = exec(admin_id: "0").dig("data", "assignSupportTicket")

    expect(payload["errors"]).to eq [ "Admin not found" ]
    expect(ticket.reload.assigned_admin).to be_nil
  end

  it "refuses a customer JWT" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(ticket.reload.assigned_admin).to be_nil
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
