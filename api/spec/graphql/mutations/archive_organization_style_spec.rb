require "rails_helper"

RSpec.describe Mutations::ArchiveOrganizationStyle, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let!(:org_style) { create(:style, name: "Acme Cover", organization:) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation ArchiveOrganizationStyle($id: ID!) {
        archiveOrganizationStyle(input: { id: $id }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def exec(id, user: admin)
    post "/graphql", params: { query:, variables: { id: id.to_s } }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "archiveOrganizationStyle")
  end

  it "lets an org admin archive their organization's asset" do
    data = exec(org_style.id)

    expect(data).to eq("success" => true, "errors" => [])
    expect(Style.find_by(id: org_style.id)).to be_nil
    expect(Style.unscoped.find(org_style.id).deleted_at).to be_present
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = exec(org_style.id, user: member)

    expect(data["success"]).to be(false)
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(org_style.reload.deleted_at).to be_nil
  end

  it "returns Not authorized for a non-member" do
    data = exec(org_style.id, user: create(:user))

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(org_style.reload.deleted_at).to be_nil
  end

  it "returns Not authorized for an admin of a different organization" do
    outsider = create(:user)
    other_organization = create(:organization, name: "Other Co", created_by: outsider)
    create(:organization_membership, :admin, organization: other_organization, user: outsider)

    data = exec(org_style.id, user: outsider)

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(org_style.reload.deleted_at).to be_nil
  end

  # The curated gallery stays with the internal admin's ArchiveCoverStyle.
  it "refuses to archive a global curated style" do
    global_style = create(:style, name: "Curated Cover")

    data = exec(global_style.id)

    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(global_style.reload.deleted_at).to be_nil
  end

  it "returns a not-found error for an unknown style" do
    expect(exec("0")["errors"]).to eq([ "Style not found" ])
  end

  it "returns a not-found error for an already-archived asset" do
    org_style.archive!
    expect(exec(org_style.id)["errors"]).to eq([ "Style not found" ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { id: org_style.id.to_s } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end
end
