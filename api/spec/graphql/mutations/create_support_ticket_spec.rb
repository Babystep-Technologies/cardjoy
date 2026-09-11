require "rails_helper"

RSpec.describe Mutations::CreateSupportTicket, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }
  let(:anonymous_headers) { { "Content-Type" => "application/json" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateSupportTicket($subject: String!, $category: String!, $body: String!) {
        createSupportTicket(input: { subject: $subject, category: $category, body: $body }) {
          supportTicket {
            externalId
            subject
            category
            status
            lastCustomerReplyAt
            messages { authorKind authorId body }
          }
          errors
        }
      }
    GRAPHQL
  end

  def create_ticket(subject: "Question about my card", category: "Account question", body: "It won't send.",
                     request_headers: headers)
    post "/graphql",
      params: { query:, variables: { subject:, category:, body: } }.to_json,
      headers: request_headers
    JSON.parse(response.body).dig("data", "createSupportTicket")
  end

  it "creates the ticket and its first customer message atomically" do
    result = create_ticket

    expect(result["errors"]).to be_empty
    ticket = result["supportTicket"]
    expect(ticket["subject"]).to eq("Question about my card")
    expect(ticket["category"]).to eq("Account question")
    expect(ticket["status"]).to eq("open")
    expect(ticket["lastCustomerReplyAt"]).to be_present
    expect(ticket["messages"].length).to eq(1)
    expect(ticket["messages"].first["authorKind"]).to eq("customer")
    expect(ticket["messages"].first["authorId"]).to eq(user.id.to_s)
    expect(ticket["messages"].first["body"]).to eq("It won't send.")

    expect(SupportTicket.count).to eq(1)
    expect(SupportTicketMessage.count).to eq(1)
  end

  it "rejects an unknown category" do
    result = create_ticket(category: "Bogus")

    expect(result["errors"]).to eq([ "Invalid category" ])
    expect(SupportTicket.count).to eq(0)
  end

  it "rejects a blank subject" do
    result = create_ticket(subject: "")

    expect(result["errors"]).to be_present
    expect(SupportTicket.count).to eq(0)
  end

  it "is rejected outright without a token" do
    post "/graphql",
      params: { query:, variables: { subject: "x", category: "Others", body: "y" } }.to_json,
      headers: anonymous_headers

    expect(response).to have_http_status(:unauthorized)
    expect(SupportTicket.count).to eq(0)
  end
end
