# typed: false

require "rails_helper"
require "jwt"

RSpec.describe Mutations::ReplyToSupportTicketByAdmin, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:owner) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:ticket) { create(:support_ticket, user: owner) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  let(:query) do
    <<~GRAPHQL
      mutation ReplyToSupportTicketByAdmin($ticketExternalId: String!, $body: String!, $newStatus: String) {
        replyToSupportTicketByAdmin(
          input: { ticketExternalId: $ticketExternalId, body: $body, newStatus: $newStatus }
        ) {
          supportTicket {
            status
            lastAdminReplyAt
            messages { authorKind body }
          }
          errors
        }
      }
    GRAPHQL
  end

  def exec(ticket_external_id: ticket.external_id, body: "We've looked into this.", new_status: nil, token: admin_token)
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{token}" if token

    post "/graphql",
      params: { query: query, variables: { ticketExternalId: ticket_external_id, body: body, newStatus: new_status } }.to_json,
      headers: headers
    JSON.parse(response.body)
  end

  it "appends the message, stamps lastAdminReplyAt, and defaults to pending" do
    payload = exec.dig("data", "replyToSupportTicketByAdmin")

    expect(payload["errors"]).to be_empty
    expect(payload.dig("supportTicket", "status")).to eq "pending"
    expect(payload.dig("supportTicket", "lastAdminReplyAt")).to be_present
    expect(payload.dig("supportTicket", "messages")).to eq(
      [ { "authorKind" => "admin", "body" => "We've looked into this." } ]
    )
  end

  it "attributes the message to the acting admin" do
    exec

    message = ticket.reload.messages.last
    expect(message.author_kind).to eq "admin"
    expect(message.author_id).to eq admin.id
  end

  it "moves the ticket to an explicit newStatus instead of pending" do
    payload = exec(new_status: "resolved").dig("data", "replyToSupportTicketByAdmin")

    expect(payload.dig("supportTicket", "status")).to eq "resolved"
  end

  it "rejects an invalid newStatus" do
    payload = exec(new_status: "sideways").dig("data", "replyToSupportTicketByAdmin")

    expect(payload["errors"]).to eq [ "Invalid status" ]
    expect(ticket.reload.messages).to be_empty
  end

  it "enqueues exactly one customer email" do
    expect { exec }.to have_enqueued_mail(SupportTicketMailer, :admin_reply).once
  end

  it "reports an unknown ticket as not found" do
    payload = exec(ticket_external_id: "NOTREAL").dig("data", "replyToSupportTicketByAdmin")

    expect(payload["errors"]).to eq [ "Support ticket not found" ]
  end

  it "refuses a customer JWT outright rather than returning a partial result" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "replyToSupportTicketByAdmin")).to be_nil
    expect(ticket.reload.messages).to be_empty
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
