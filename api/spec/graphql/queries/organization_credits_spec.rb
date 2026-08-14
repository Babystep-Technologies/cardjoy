require "rails_helper"

# The credit-pool fields on OrganizationType, which back the organization
# credits page (#128). Read through `viewer`, the way the client reaches them.
RSpec.describe "Organization credits", type: :request do
  let(:admin) { create(:user, name: "Dana Host") }
  let(:member) { create(:user, name: "Sam Member") }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:query) do
    <<~GRAPHQL
      query Viewer($limit: Int) {
        viewer {
          activeOrganization {
            creditBalance
            credits(limit: $limit) {
              id
              amount
              reason
              actor { name }
              member { name }
            }
          }
        }
      }
    GRAPHQL
  end

  def exec(user, limit: nil)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    post "/graphql",
      params: { query: query, variables: { limit: limit } }.to_json,
      headers: { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
    JSON.parse(response.body).dig("data", "viewer", "activeOrganization")
  end

  def event(kind, data)
    { event_kind: kind, event_happened_at: Time.now.utc.iso8601(3), event_data: data }
  end

  # Stripe metadata comes back as strings, so the purchased-by id is written as
  # one — the ledger has to resolve it all the same.
  def purchase!(amount:, buyer:)
    create(:organization_credit, organization: organization, amount: amount, reason: "purchase",
      events: [ event("org_credit_purchased", { purchased_by_user_id: buyer.id.to_s, amount: amount }) ])
  end

  def allocation!(amount:, to:, by:)
    create(:organization_credit, organization: organization, amount: -amount, reason: "org_allocation",
      events: [ event("org_credit_allocated",
        { organization_id: organization.id, user_id: to.id, allocated_by_user_id: by.id, amount: amount }) ])
  end

  before do
    create(:organization_membership, :admin, organization: organization, user: admin)
    create(:organization_membership, organization: organization, user: member)
    admin.update!(active_organization: organization)
    member.update!(active_organization: organization)
  end

  it "returns the pool balance as the signed sum of the ledger" do
    purchase!(amount: 10, buyer: admin)
    allocation!(amount: 4, to: member, by: admin)

    expect(exec(admin)["creditBalance"]).to eq(6)
  end

  it "returns the ledger newest first, naming who is on each row" do
    purchase!(amount: 10, buyer: admin)
    allocation!(amount: 4, to: member, by: admin)

    rows = exec(admin)["credits"]

    expect(rows.map { |row| row["amount"] }).to eq([ -4, 10 ])
    expect(rows.first).to include(
      "reason" => "org_allocation",
      "actor" => { "name" => "Dana Host" },
      "member" => { "name" => "Sam Member" }
    )
    expect(rows.last).to include(
      "reason" => "purchase",
      "actor" => { "name" => "Dana Host" },
      "member" => nil
    )
  end

  it "names nobody on a row that no person initiated" do
    create(:organization_credit, organization: organization, amount: -10, reason: "chargeback",
      events: [ event("org_credit_reversed_due_to_chargeback", { original_credit_id: 1 }) ])

    expect(exec(admin)["credits"].first).to include("actor" => nil, "member" => nil)
  end

  it "caps the ledger at the requested number of rows" do
    3.times { purchase!(amount: 1, buyer: admin) }

    expect(exec(admin, limit: 2)["credits"].length).to eq(2)
  end

  # A member reads the balance to know what the pool holds; who bought it and
  # who it went to is the admins' ledger.
  it "shows a plain member the balance but not the ledger" do
    purchase!(amount: 10, buyer: admin)

    expect(exec(member)).to eq("creditBalance" => 10, "credits" => [])
  end

  # Mirrors the roster spec: nothing hands an OrganizationType to a non-member
  # today, and the guard is here so nothing later can.
  it "returns no ledger to someone who does not belong to the organization" do
    outsider = create(:user)
    User.where(id: outsider.id).update_all(active_organization_id: organization.id)
    purchase!(amount: 10, buyer: admin)

    expect(exec(outsider)["credits"]).to be_empty
  end
end
