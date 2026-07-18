require "rails_helper"

RSpec.describe "UpcomingOccasions", type: :request do
  let(:user) { create(:user) }
  let(:contact) { create(:contact, user:) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, "HS256") }
  let(:headers) { { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" } }

  let(:query) do
    <<~GRAPHQL
      query UpcomingOccasions($withinDays: Int) {
        upcomingOccasions(withinDays: $withinDays) { id kind nextOccurrence contact { name } }
      }
    GRAPHQL
  end

  def exec(variables = {})
    post "/graphql", params: { query:, variables: }.to_json, headers: headers
    JSON.parse(response.body).dig("data", "upcomingOccasions")
  end

  it "returns the caller's occasions within the window, soonest first" do
    in_5 = Date.current + 5.days
    in_20 = Date.current + 20.days
    soon = create(:occasion, contact:, kind: "Birthday", recurring: true,
      occurs_on: Date.new(1990, in_5.month, in_5.day))
    later = create(:occasion, contact:, kind: "Work anniversary", recurring: true,
      occurs_on: Date.new(1990, in_20.month, in_20.day))

    result = exec({ withinDays: 30 })
    expect(result.map { |o| o["id"] }).to eq([ soon.id.to_s, later.id.to_s ])

    result = exec({ withinDays: 10 })
    expect(result.map { |o| o["id"] }).to eq([ soon.id.to_s ])
  end

  it "defaults to a 30-day window" do
    in_5 = Date.current + 5.days
    create(:occasion, contact:, occurs_on: Date.new(1990, in_5.month, in_5.day), recurring: true)
    expect(exec.length).to eq(1)
  end

  it "excludes other users' occasions" do
    other_contact = create(:contact)
    create(:occasion, contact: other_contact, occurs_on: Date.current + 1.day, recurring: true)
    expect(exec({ withinDays: 30 })).to eq([])
  end
end
