require "rails_helper"

RSpec.describe Mutations::UpdateOccasion, type: :request do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, user:) }
  let(:occasion) { create(:occasion, contact:, kind: "Birthday", recurring: true) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      mutation UpdateOccasion($occasionId: ID!, $kind: String, $occursOn: ISO8601Date, $recurring: Boolean) {
        updateOccasion(input: { occasionId: $occasionId, kind: $kind, occursOn: $occursOn, recurring: $recurring }) {
          occasion { id kind occursOn recurring }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "updateOccasion")
  end

  it "updates the caller's occasion, including setting recurring to false" do
    data = exec(occasionId: occasion.id, kind: "Graduation", occursOn: "2026-05-20", recurring: false)
    expect(data["errors"]).to be_empty
    expect(data["occasion"]).to include("kind" => "Graduation", "occursOn" => "2026-05-20", "recurring" => false)
  end

  it "does not update another user's occasion" do
    other = create(:occasion, kind: "Birthday")
    data = exec(occasionId: other.id, kind: "Graduation")
    expect(data["occasion"]).to be_nil
    expect(data["errors"]).to include("Occasion not found or not owned by user")
    expect(other.reload.kind).to eq("Birthday")
  end
end
