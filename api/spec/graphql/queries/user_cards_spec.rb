require "rails_helper"

RSpec.describe Queries::UserCards, type: :request do
  let(:owner) { create(:user) }
  let(:member) { create(:user) }
  let(:stranger) { create(:user) }
  let(:organization) { create(:organization) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before do
    create(:organization_membership, organization:, user: owner)
    create(:organization_membership, organization:, user: member)
  end

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      query UserCards($userId: ID!, $organizationId: ID) {
        userCards(userId: $userId, organizationId: $organizationId) {
          title
          organization { id name }
        }
      }
    GRAPHQL
  end

  def exec(user:, organization_id: nil)
    post "/graphql",
         params: { query:, variables: { userId: user.id, organizationId: organization_id } }.to_json,
         headers: headers_for(user)
    JSON.parse(response.body).dig("data", "userCards")
  end

  let!(:org_card) { create(:card, user: owner, organization:, title: "Team card") }
  let!(:personal_card) { create(:card, user: owner, organization: nil, title: "My card") }

  it "shows an organization's cards to every member, whoever created them" do
    titles = exec(user: member, organization_id: organization.id).map { |c| c["title"] }

    expect(titles).to contain_exactly("Team card")
  end

  it "keeps organization cards out of the creator's Personal list" do
    titles = exec(user: owner).map { |c| c["title"] }

    expect(titles).to contain_exactly("My card")
  end

  it "returns nothing when a non-member asks for the organization's cards" do
    expect(exec(user: stranger, organization_id: organization.id)).to eq([])
  end

  it "returns nothing for an organization id that does not exist" do
    expect(exec(user: member, organization_id: "0")).to eq([])
  end

  # Regression for the untouched path: a user with no organizations at all must
  # see exactly what they saw before organizations existed.
  it "is unchanged for a user who belongs to no organization" do
    solo = create(:user)
    create(:card, user: solo, title: "Solo card")

    titles = exec(user: solo).map { |c| c["title"] }

    expect(titles).to contain_exactly("Solo card")
  end

  it "reports which organization owns a card" do
    row = exec(user: member, organization_id: organization.id).first

    expect(row.dig("organization", "id")).to eq(organization.id.to_s)
    expect(exec(user: owner).first["organization"]).to be_nil
  end
end
