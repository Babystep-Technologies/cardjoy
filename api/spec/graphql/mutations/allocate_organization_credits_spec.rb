require "rails_helper"

RSpec.describe Mutations::AllocateOrganizationCredits, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, created_by: admin) }
  let(:member) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before do
    create(:organization_membership, :admin, organization:, user: admin)
    create(:organization_membership, organization:, user: member)
    create(:organization_credit, organization:, amount: 10)
  end

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation AllocateOrganizationCredits($organizationId: ID!, $userId: ID!, $amount: Int!) {
        allocateOrganizationCredits(
          input: { organizationId: $organizationId, userId: $userId, amount: $amount }
        ) {
          organization { id creditBalance }
          member { id creditBalance }
          errors
        }
      }
    GRAPHQL
  end

  def exec(amount, user: admin, organization_id: organization.id, user_id: member.id)
    post "/graphql",
         params: { query:, variables: { organizationId: organization_id, userId: user_id, amount: } }.to_json,
         headers: headers_for(user)
    JSON.parse(response.body).dig("data", "allocateOrganizationCredits")
  end

  it "allocates credits and returns both new balances" do
    data = exec(4)

    expect(data["errors"]).to be_empty
    expect(data.dig("organization", "creditBalance")).to eq(6)
    expect(data.dig("member", "creditBalance")).to eq(User::SIGNUP_CREDIT_GRANT + 4)
    expect(organization.credit_balance).to eq(6)
    expect(member.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT + 4)
  end

  it "refuses to allocate more than the pool holds and changes nothing" do
    data = exec(11)

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to eq([ described_class::INSUFFICIENT_POOL_CREDITS_ERROR ])
    expect(organization.credit_balance).to eq(10)
    expect(member.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
  end

  it "rejects a zero or negative amount" do
    expect(exec(0)["errors"]).to eq([ described_class::INVALID_AMOUNT_ERROR ])
    expect(exec(-3)["errors"]).to eq([ described_class::INVALID_AMOUNT_ERROR ])

    expect(organization.credit_balance).to eq(10)
  end

  it "rejects a recipient who is not a member of the organization" do
    stranger = create(:user)

    data = exec(1, user_id: stranger.id)

    expect(data["errors"]).to eq([ described_class::NOT_A_MEMBER_ERROR ])
    expect(organization.credit_balance).to eq(10)
    expect(stranger.credit_balance).to eq(User::SIGNUP_CREDIT_GRANT)
  end

  it "returns Not authorized for a member who is not an admin" do
    data = exec(1, user: member)

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(organization.credit_balance).to eq(10)
  end

  it "returns Not authorized for someone outside the organization" do
    data = exec(1, user: create(:user))

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(organization.credit_balance).to eq(10)
  end

  it "is challenged before the resolver runs when there is no token" do
    post "/graphql",
         params: { query:, variables: { organizationId: organization.id, userId: member.id, amount: 1 } }.to_json,
         headers: { "Content-Type" => "application/json" } # no Authorization header

    # Stopped at the controller gate: this is not a public operation, so it
    # never reaches the resolver's own "Not authenticated" check.
    expect(response).to have_http_status(:unauthorized)
    expect(organization.credit_balance).to eq(10)
  end

  it "returns Organization not found for an unknown organization" do
    data = exec(1, organization_id: "0")

    expect(data["errors"]).to eq([ described_class::NOT_FOUND_ERROR ])
  end

  it "returns User not found for an unknown recipient" do
    data = exec(1, user_id: "0")

    expect(data["errors"]).to eq([ described_class::USER_NOT_FOUND_ERROR ])
    expect(organization.credit_balance).to eq(10)
  end

  it "lets the member spend the allocated credits on a card" do
    spender = create(:user, :without_signup_credits)
    create(:organization_membership, organization:, user: spender)
    exec(2, user_id: spender.id)

    create_card = <<~GRAPHQL
      mutation CreateOneOnOneCard($title: String!, $recipient: String!, $text: String!) {
        createOneOnOneCard(input: { title: $title, recipient: $recipient, text: $text }) {
          card { id }
          errors
        }
      }
    GRAPHQL
    post "/graphql",
         params: {
           query: create_card,
           variables: { title: "Thanks", recipient: "sam@example.com", text: "You're the best" }
         }.to_json,
         headers: headers_for(spender)

    data = JSON.parse(response.body).dig("data", "createOneOnOneCard")
    expect(data["errors"]).to be_empty
    expect(data["card"]).to be_present
    expect(spender.credit_balance).to eq(1)
  end
end
