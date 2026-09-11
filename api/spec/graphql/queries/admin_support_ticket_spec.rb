# typed: false

require "rails_helper"
require "jwt"

RSpec.describe "Admin support ticket", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:owner) { create(:user, name: "Dana Host", email: "dana@example.com") }
  let(:ticket) { create(:support_ticket, user: owner, subject: "Billing question") }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  def exec(external_id:, token: admin_token)
    post "/graphql",
      params: { query: query, variables: { externalId: external_id } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  let(:query) do
    <<~GRAPHQL
      query AdminSupportTicket($externalId: String!) {
        adminSupportTicket(externalId: $externalId) {
          subject
          status
          customer { name email }
          assignedAdmin { id }
          messages {
            authorKind
            authorName
            authorEmail
            body
          }
        }
      }
    GRAPHQL
  end

  it "rejects a customer JWT" do
    body = exec(external_id: ticket.external_id, token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
  end

  it "returns null for an id that doesn't exist, rather than an error" do
    data = exec(external_id: "NOTREAL").dig("data", "adminSupportTicket")

    expect(data).to be_nil
  end

  it "returns the customer and assignment" do
    ticket.assign_to!(admin: admin)

    data = exec(external_id: ticket.external_id).dig("data", "adminSupportTicket")

    expect(data["customer"]).to eq("name" => "Dana Host", "email" => "dana@example.com")
    expect(data["assignedAdmin"]).to eq("id" => admin.id.to_s)
  end

  it "returns the full ordered thread with each message's author identity" do
    create(:support_ticket_message, support_ticket: ticket, author_id: owner.id, body: "First message",
      created_at: 2.hours.ago)
    create(:support_ticket_message, :admin, support_ticket: ticket, author_id: admin.id,
      body: "Staff reply", created_at: 1.hour.ago)

    messages = exec(external_id: ticket.external_id).dig("data", "adminSupportTicket", "messages")

    expect(messages.map { |m| m["body"] }).to eq [ "First message", "Staff reply" ]
    expect(messages.first).to include("authorKind" => "customer", "authorName" => owner.name, "authorEmail" => owner.email)
    expect(messages.second).to include("authorKind" => "admin", "authorName" => admin.name, "authorEmail" => admin.email)
  end
end
