require "rails_helper"

RSpec.describe Mutations::DeleteOccasion, type: :request do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, user:) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation DeleteOccasion($occasionId: ID!) {
        deleteOccasion(input: { occasionId: $occasionId }) { success errors }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "deleteOccasion")
  end

  it "deletes the caller's occasion" do
    occasion = create(:occasion, contact:)
    expect { exec(occasionId: occasion.id) }.to change(Occasion, :count).by(-1)
  end

  it "does not delete another user's occasion" do
    other = create(:occasion)
    data = exec(occasionId: other.id)
    expect(data["success"]).to be false
    expect(data["errors"]).to include("Occasion not found or not owned by user")
    expect(Occasion.exists?(other.id)).to be true
  end
end
