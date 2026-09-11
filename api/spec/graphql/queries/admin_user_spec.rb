# typed: false

require "rails_helper"
require "jwt"

# The user detail page (#180): the profile a support agent lands on from a
# ticket, the users list, or an organization's roster.
RSpec.describe Queries::AdminUser, type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user, name: "Dana Host") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  let(:query) do
    <<~GRAPHQL
      query AdminUser($id: ID!, $creditsLimit: Int, $creditsPage: Int) {
        adminUser(id: $id) {
          id
          email
          name
          emailConfirmed
          creditBalance
          activeOrganization { id name }
          credits(limit: $creditsLimit, page: $creditsPage) { amount reason note }
          creditsCount
          cards { id title }
          cardsCount
          invitations { id title }
          invitationsCount
          holidayCards { id title }
          holidayCardsCount
        }
      }
    GRAPHQL
  end

  def exec(id: user.id, token: admin_token, **extra_variables)
    post "/graphql",
      params: { query: query, variables: { id: id, **extra_variables } }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  def data(**args)
    exec(**args).dig("data", "adminUser")
  end

  it "returns the profile" do
    organization = create(:organization, created_by: user)
    create(:organization_membership, organization: organization, user: user)
    user.update!(active_organization: organization, email_confirmed: true)

    result = data

    expect(result).to include(
      "id" => user.id.to_s,
      "email" => user.email,
      "name" => "Dana Host",
      "emailConfirmed" => true,
      "creditBalance" => user.credit_balance
    )
    expect(result["activeOrganization"]).to eq("id" => organization.id.to_s, "name" => organization.name)
  end

  it "reports Personal as a null active organization, not a missing field" do
    result = data

    expect(result["activeOrganization"]).to be_nil
  end

  it "paginates the personal ledger newest first" do
    create_list(:credit, 4, user: user, amount: 1)

    first_page = data(creditsLimit: 2, creditsPage: 1)
    expect(first_page["creditsCount"]).to eq user.credits.count
    expect(first_page["credits"].size).to eq 2

    second_page = data(creditsLimit: 2, creditsPage: 2)
    ids_seen = (first_page["credits"] + second_page["credits"]).size
    expect(ids_seen).to eq [ user.credits.count, 4 ].min
  end

  it "surfaces an admin_adjustment row's note" do
    create(:credit, user: user, amount: 10, reason: "admin_adjustment",
      events: [ { event_kind: "admin_adjustment", event_happened_at: Time.now.utc.iso8601(3),
                  event_data: { note: "Goodwill credit" } } ])

    row = data["credits"].find { |credit| credit["reason"] == "admin_adjustment" }
    expect(row["note"]).to eq "Goodwill credit"
  end

  it "returns the 10 most recent cards, invitations, and holiday cards, with full counts" do
    create_list(:card, 12, user: user)
    create_list(:invitation, 2, user: user)
    create(:holiday_card, user: user)

    result = data

    expect(result["cards"].size).to eq 10
    expect(result["cardsCount"]).to eq 12
    expect(result["invitations"].size).to eq 2
    expect(result["invitationsCount"]).to eq 2
    expect(result["holidayCards"].size).to eq 1
    expect(result["holidayCardsCount"]).to eq 1
  end

  it "returns null for an unknown id" do
    body = exec(id: "0")

    expect(body.dig("data", "adminUser")).to be_nil
    expect(body["errors"]).to be_nil
  end

  it "refuses a regular user's token outright rather than returning a partial result" do
    body = exec(token: user_token)

    expect(body["errors"].first["message"]).to eq "Not authorized"
    expect(body.dig("data", "adminUser")).to be_nil
  end

  it "answers an unauthenticated request with 401" do
    exec(token: nil)

    expect(response).to have_http_status(:unauthorized)
  end
end
