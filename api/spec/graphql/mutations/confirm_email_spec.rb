require 'rails_helper'
require 'jwt'

RSpec.describe Mutations::ConfirmEmail, type: :request do
  let(:user) do
    create(:user,
      email: "test@example.com",
      email_confirmed: false,
      confirmation_code: "123456",
      confirmation_sent_at: 10.minutes.ago
    )
  end

  let(:jwt_secret) { Rails.application.credentials.dig(:jwt, :secret) || ENV["JWT_SECRET_KEY"] }

  let(:token) do
    JWT.encode({ user_id: user.id }, jwt_secret, "HS256")
  end

  let(:headers) do
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation ConfirmEmail($email: String!, $code: String!) {
        confirmEmail(input: { email: $email, code: $code }) {
          user {
            id
            email
          }
          token
          errors
        }
      }
    GRAPHQL
  end

  def execute_mutation(email:, code:, custom_headers: headers)
    post "/graphql",
      params: {
        query: query,
        variables: { email: email, code: code }
      }.to_json,
      headers: custom_headers
  end

  context "when confirmation is successful" do
    it "returns the user and a valid token" do
      execute_mutation(email: user.email, code: "123456")

      json = JSON.parse(response.body)
      data = json.dig("data", "confirmEmail")

      expect(data["errors"]).to be_empty
      expect(data["user"]["email"]).to eq(user.email)
      expect(data["token"]).to be_present

      # Token payload validation
      decoded = JWT.decode(data["token"], jwt_secret, true, { algorithm: "HS256" }).first
      expect(decoded["user_id"]).to eq(user.id)
      expect(decoded["email"]).to eq(user.email)

      expect(user.reload.email_confirmed).to eq(true)
    end
  end

  context "when user is not found" do
    it "returns a user not found error" do
      execute_mutation(email: "missing@example.com", code: "123456")

      json = JSON.parse(response.body)
      data = json.dig("data", "confirmEmail")

      expect(data["user"]).to be_nil
      expect(data["token"]).to be_nil
      expect(data["errors"]).to include("User not found")
    end
  end

  context "when email is already confirmed" do
    before { user.update(email_confirmed: true) }

    it "returns an already verified error" do
      execute_mutation(email: user.email, code: "123456")

      json = JSON.parse(response.body)
      data = json.dig("data", "confirmEmail")

      expect(data["errors"]).to include("Already verified")
    end
  end

  context "when confirmation code is expired" do
    before do
      user.update(confirmation_sent_at: 3.hours.ago)
      allow_any_instance_of(User).to receive(:confirmation_code_expired?).and_return(true)
    end

    it "returns a code expired error" do
      execute_mutation(email: user.email, code: "123456")

      json = JSON.parse(response.body)
      data = json.dig("data", "confirmEmail")

      expect(data["errors"]).to include("Code expired")
    end
  end

  context "when confirmation code is invalid" do
    it "returns an invalid code error" do
      execute_mutation(email: user.email, code: "wrong-code")

      json = JSON.parse(response.body)
      data = json.dig("data", "confirmEmail")

      expect(data["errors"]).to include("Invalid code")
    end
  end

  context "when no Authorization header is present" do
    it "returns a 401 Unauthorized" do
      execute_mutation(email: user.email, code: "123456", custom_headers: { "Content-Type" => "application/json" })

      json = JSON.parse(response.body)
      expect(response.status).to eq(401)
      expect(json["errors"]).to include("Unauthorized")
    end
  end
end
