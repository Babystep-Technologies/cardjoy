require "rails_helper"

RSpec.describe Queries::Styles, type: :request do
  let(:admin) { create(:user) }
  let(:member) { create(:user) }
  let(:organization) { create(:organization, created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let!(:global_style) { create(:style, name: "Curated Cover") }
  let!(:org_style) { create(:style, name: "Acme Cover", organization:) }

  before do
    create(:organization_membership, :admin, organization:, user: admin)
    create(:organization_membership, organization:, user: member)
  end

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      query GetStyles($organizationId: ID) {
        styles(kind: "cover", organizationId: $organizationId) {
          id
          name
          organizationId
        }
      }
    GRAPHQL
  end

  def names_for(user, organization_id: nil)
    post "/graphql",
      params: { query:, variables: { organizationId: organization_id&.to_s } }.to_json,
      headers: headers_for(user)
    JSON.parse(response.body).dig("data", "styles").map { |style| style["name"] }
  end

  it "shows a member the organization's assets alongside the global gallery" do
    expect(names_for(member, organization_id: organization.id)).to contain_exactly("Curated Cover", "Acme Cover")
  end

  it "returns only global curated styles when no organizationId is given" do
    expect(names_for(admin)).to contain_exactly("Curated Cover")
  end

  it "hides an organization's assets from a member of a different organization" do
    outsider = create(:user)
    other_organization = create(:organization, name: "Other Co", created_by: outsider)
    create(:organization_membership, :admin, organization: other_organization, user: outsider)

    expect(names_for(outsider, organization_id: organization.id)).to contain_exactly("Curated Cover")
  end

  it "hides an organization's assets from a non-member" do
    expect(names_for(create(:user), organization_id: organization.id)).to contain_exactly("Curated Cover")
  end

  it "drops an archived organization asset out of the picker" do
    org_style.archive!

    expect(names_for(member, organization_id: organization.id)).to contain_exactly("Curated Cover")
  end

  it "exposes organizationId so the picker can group an organization's own assets" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id.to_s } }.to_json,
      headers: headers_for(member)
    styles = JSON.parse(response.body).dig("data", "styles")

    expect(styles.find { |style| style["name"] == "Acme Cover" }["organizationId"]).to eq(organization.id.to_s)
    expect(styles.find { |style| style["name"] == "Curated Cover" }["organizationId"]).to be_nil
  end

  # GetStyles is in GraphqlController::PUBLIC_OPERATIONS, so the picker also
  # loads for a signed-out visitor. They get the global gallery and nothing else.
  it "returns only global curated styles for a signed-out visitor" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id.to_s }, operationName: "GetStyles" }.to_json,
      headers: { "Content-Type" => "application/json" }

    names = JSON.parse(response.body).dig("data", "styles").map { |style| style["name"] }
    expect(names).to contain_exactly("Curated Cover")
  end
end
