require "rails_helper"

RSpec.describe Queries::UserInvitations, type: :request do
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
      query UserInvitations($userId: ID!, $organizationId: ID) {
        userInvitations(userId: $userId, organizationId: $organizationId) {
          title
          organization { id }
        }
      }
    GRAPHQL
  end

  def exec(user:, organization_id: nil)
    post "/graphql",
         params: { query:, variables: { userId: user.id, organizationId: organization_id } }.to_json,
         headers: headers_for(user)
    JSON.parse(response.body).dig("data", "userInvitations")
  end

  let!(:org_invitation) { create(:invitation, user: owner, organization:, title: "Team offsite") }
  let!(:personal_invitation) { create(:invitation, user: owner, organization: nil, title: "My party") }

  it "shows an organization's invitations to every member" do
    titles = exec(user: member, organization_id: organization.id).map { |i| i["title"] }

    expect(titles).to contain_exactly("Team offsite")
  end

  it "keeps organization invitations out of the creator's Personal list" do
    titles = exec(user: owner).map { |i| i["title"] }

    expect(titles).to contain_exactly("My party")
  end

  it "returns nothing when a non-member asks for the organization's invitations" do
    expect(exec(user: stranger, organization_id: organization.id)).to eq([])
  end

  it "is unchanged for a user who belongs to no organization" do
    solo = create(:user)
    create(:invitation, user: solo, title: "Solo dinner")

    titles = exec(user: solo).map { |i| i["title"] }

    expect(titles).to contain_exactly("Solo dinner")
  end
end
