require "rails_helper"

# createSupportRequest is deprecated in favor of createSupportTicket (#172),
# but stays working until #175 ships the UI that switches over.
RSpec.describe Mutations::CreateSupportRequest, type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation CreateSupportRequest($reason: String!, $message: String!, $userEmail: String!) {
        createSupportRequest(input: { reason: $reason, message: $message, userEmail: $userEmail }) {
          success
        }
      }
    GRAPHQL
  end

  it "still sends the case email" do
    expect {
      post "/graphql",
        params: { query:, variables: { reason: "Account question", message: "Help!", userEmail: user.email } }.to_json,
        headers: headers
    }.to have_enqueued_mail(SupportMailer, :send_case_email)

    result = JSON.parse(response.body).dig("data", "createSupportRequest")
    expect(result["success"]).to be(true)
  end

  it "is marked deprecated on the schema" do
    field = ApiSchema.mutation.fields["createSupportRequest"]

    expect(field.deprecation_reason).to be_present
  end
end
