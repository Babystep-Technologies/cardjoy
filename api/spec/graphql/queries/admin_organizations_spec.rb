# typed: false

require "rails_helper"
require "jwt"

# The organizations section of the admin dashboard (#130): the list support
# scans and the detail view it drills into.
RSpec.describe "Admin organizations", type: :request do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:owner) { create(:user, name: "Dana Host") }
  let(:member) { create(:user, name: "Sam Member") }
  let!(:organization) { create(:organization, name: "Acme Corp", created_by: owner) }

  def headers_for(token)
    { "Content-Type" => "application/json" }.tap do |headers|
      headers["Authorization"] = "Bearer #{token}" if token
    end
  end

  def admin_token = JWT.encode({ admin_id: admin.id }, secret, "HS256")
  def user_token = JWT.encode({ user_id: user.id }, secret, "HS256")

  def exec(query, variables: {}, token: admin_token)
    post "/graphql",
      params: { query: query, variables: variables }.to_json,
      headers: headers_for(token)
    JSON.parse(response.body)
  end

  def event(kind, data)
    { event_kind: kind, event_happened_at: Time.now.utc.iso8601(3), event_data: data }
  end

  describe "the list" do
    let(:query) do
      <<~GRAPHQL
        query AdminOrganizations($page: Int, $perPage: Int, $search: String) {
          adminOrganizations(page: $page, perPage: $perPage, search: $search) {
            organizations { id name slug membersCount creditBalance createdAt }
            totalCount
            page
            perPage
            totalPages
          }
        }
      GRAPHQL
    end

    before do
      create(:organization_membership, :admin, organization: organization, user: owner)
      create(:organization_membership, organization: organization, user: member)
      create(:organization_credit, organization: organization, amount: 10, reason: "purchase")
      create(:organization_credit, organization: organization, amount: -4, reason: "org_allocation")
    end

    it "returns organizations newest first with member count and pool balance" do
      newer = create(:organization, name: "Beta Inc", created_by: owner)

      data = exec(query, variables: { page: 1, perPage: 20 }).dig("data", "adminOrganizations")

      expect(data["totalCount"]).to eq 2
      expect(data["organizations"].map { |org| org["name"] }).to eq [ "Beta Inc", "Acme Corp" ]
      expect(data["organizations"].last).to include(
        "id" => organization.id.to_s,
        "slug" => organization.slug,
        "membersCount" => 2,
        "creditBalance" => 6
      )
      expect(data["organizations"].first).to include("id" => newer.id.to_s, "membersCount" => 0)
    end

    it "filters on name or slug" do
      create(:organization, name: "Beta Inc", created_by: owner)

      data = exec(query, variables: { search: "acme" }).dig("data", "adminOrganizations")

      expect(data["totalCount"]).to eq 1
      expect(data["organizations"].first["name"]).to eq "Acme Corp"
    end

    it "pages the results" do
      create(:organization, name: "Beta Inc", created_by: owner)

      data = exec(query, variables: { page: 2, perPage: 1 }).dig("data", "adminOrganizations")

      expect(data["totalCount"]).to eq 2
      expect(data["totalPages"]).to eq 2
      expect(data["organizations"].map { |org| org["name"] }).to eq [ "Acme Corp" ]
    end

    # deleteOrganization is a soft delete; a deleted customer account is not
    # something support acts on, so it stays out of the list entirely.
    it "excludes archived organizations" do
      organization.archive!

      data = exec(query).dig("data", "adminOrganizations")

      expect(data["totalCount"]).to eq 0
      expect(data["organizations"]).to be_empty
    end

    it "refuses a regular user's token outright rather than returning a partial result" do
      body = exec(query, token: user_token)

      expect(body["errors"].first["message"]).to eq "Not authorized"
      expect(body.dig("data", "adminOrganizations")).to be_nil
    end

    it "answers an unauthenticated request with 401" do
      exec(query, token: nil)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "the detail view" do
    let(:query) do
      <<~GRAPHQL
        query AdminOrganization($id: ID!) {
          adminOrganization(id: $id) {
            id
            name
            slug
            description
            membersCount
            creditBalance
            memberships { role user { id name email creditBalance } }
            credits { amount reason actor { name } member { name } }
          }
        }
      GRAPHQL
    end

    def detail(token: admin_token)
      exec(query, variables: { id: organization.id }, token: token)
    end

    before do
      create(:organization_membership, :admin, organization: organization, user: owner)
      create(:organization_membership, organization: organization, user: member)
      create(:credit, user: member, amount: 3)
    end

    # Balances are asserted against the users' own `credit_balance` rather than
    # a literal, because a new account starts with a signup bonus.
    it "returns the roster with roles and each member's personal balance" do
      data = detail.dig("data", "adminOrganization")

      expect(data).to include("name" => "Acme Corp", "membersCount" => 2)
      expect(data["memberships"]).to eq [
        { "role" => "admin", "user" => { "id" => owner.id.to_s, "name" => "Dana Host", "email" => owner.email, "creditBalance" => owner.credit_balance } },
        { "role" => "member", "user" => { "id" => member.id.to_s, "name" => "Sam Member", "email" => member.email, "creditBalance" => member.credit_balance } }
      ]
      expect(member.credit_balance).to eq owner.credit_balance + 3
    end

    it "returns the pool ledger newest first, naming who is on each row" do
      create(:organization_credit, organization: organization, amount: 10, reason: "purchase",
        events: [ event("org_credit_purchased", { purchased_by_user_id: owner.id.to_s, amount: 10 }) ])
      create(:organization_credit, organization: organization, amount: -4, reason: "org_allocation",
        events: [ event("org_credit_allocated",
          { organization_id: organization.id, user_id: member.id, allocated_by_user_id: owner.id, amount: 4 }) ])

      data = detail.dig("data", "adminOrganization")

      expect(data["creditBalance"]).to eq 6
      expect(data["credits"].map { |row| row["amount"] }).to eq [ -4, 10 ]
      expect(data["credits"].first).to include(
        "reason" => "org_allocation",
        "actor" => { "name" => "Dana Host" },
        "member" => { "name" => "Sam Member" }
      )
    end

    it "returns null for an archived organization" do
      organization.archive!

      expect(detail.dig("data", "adminOrganization")).to be_nil
    end

    it "returns null for an unknown id" do
      body = exec(query, variables: { id: "0" })

      expect(body.dig("data", "adminOrganization")).to be_nil
      expect(body["errors"]).to be_nil
    end

    it "refuses a regular user's token outright rather than returning a partial result" do
      body = detail(token: user_token)

      expect(body["errors"].first["message"]).to eq "Not authorized"
      expect(body.dig("data", "adminOrganization")).to be_nil
    end

    it "answers an unauthenticated request with 401" do
      detail(token: nil)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
