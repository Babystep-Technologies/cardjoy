require "rails_helper"

RSpec.describe Mutations::ReplyToSupportTicket, type: :request do
  let(:user) { create(:user) }
  let(:stranger) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:ticket) { create(:support_ticket, user:) }

  let(:query) do
    <<~GRAPHQL
      mutation ReplyToSupportTicket($ticketExternalId: String!, $body: String!) {
        replyToSupportTicket(input: { ticketExternalId: $ticketExternalId, body: $body }) {
          supportTicket {
            status
            lastCustomerReplyAt
            messages { authorKind body }
          }
          errors
        }
      }
    GRAPHQL
  end

  def reply(ticket_external_id: ticket.external_id, body: "Following up.", request_headers: headers)
    post "/graphql",
      params: { query:, variables: { ticketExternalId: ticket_external_id, body: } }.to_json,
      headers: request_headers
    JSON.parse(response.body).dig("data", "replyToSupportTicket")
  end

  it "appends a customer message and updates lastCustomerReplyAt" do
    freeze_time do
      result = reply

      expect(result["errors"]).to be_empty
      expect(result.dig("supportTicket", "lastCustomerReplyAt")).to eq(Time.current.iso8601)
      messages = result.dig("supportTicket", "messages")
      expect(messages.last["authorKind"]).to eq("customer")
      expect(messages.last["body"]).to eq("Following up.")
    end
  end

  it "moves a pending ticket back to open" do
    ticket.update!(status: "pending")

    result = reply

    expect(result.dig("supportTicket", "status")).to eq("open")
  end

  it "leaves a resolved ticket's status untouched" do
    ticket.update!(status: "resolved")

    result = reply

    expect(result.dig("supportTicket", "status")).to eq("resolved")
  end

  it "returns the same not-found error for someone else's ticket as for an unknown one" do
    others_ticket = create(:support_ticket, user: stranger)

    own_answer = reply(ticket_external_id: "ZZZZZZZ")
    strangers_answer = reply(ticket_external_id: others_ticket.external_id)

    expect(own_answer["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
    expect(strangers_answer["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
    expect(others_ticket.reload.messages.count).to eq(0)
  end

  it "is rejected outright without a token" do
    post "/graphql",
      params: { query:, variables: { ticketExternalId: ticket.external_id, body: "x" } }.to_json,
      headers: anonymous_headers

    expect(response).to have_http_status(:unauthorized)
    expect(ticket.reload.messages.count).to eq(0)
  end
end
