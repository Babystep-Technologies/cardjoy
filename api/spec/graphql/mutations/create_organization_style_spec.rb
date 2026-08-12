require "rails_helper"

RSpec.describe Mutations::CreateOrganizationStyle, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  let(:file) do
    fixture_file_upload(Rails.root.join("spec/fixtures/files/test_image.jpg"), "image/jpeg")
  end

  let(:query) do
    <<~GRAPHQL
      mutation CreateOrganizationStyle($organizationId: ID!, $image: Upload!, $name: String, $kind: String) {
        createOrganizationStyle(
          input: { organizationId: $organizationId, image: $image, name: $name, kind: $kind }
        ) {
          style { id name kind value organizationId }
          errors
        }
      }
    GRAPHQL
  end

  # The upload has to travel as multipart, so the variables go through the
  # GraphQL multipart `operations`/`map` pair rather than a JSON body.
  def exec(variables, user: admin)
    operations = { query:, variables: variables.merge(image: nil) }

    post "/graphql",
      params: {
        operations: operations.to_json,
        map: { "0" => [ "variables.image" ] }.to_json,
        "0" => file
      },
      headers: { "Authorization" => "Bearer #{JWT.encode({ user_id: user.id }, secret, 'HS256')}" }

    JSON.parse(response.body).dig("data", "createOrganizationStyle")
  end

  it "lets an org admin upload a cover asset scoped to their organization" do
    data = exec({ organizationId: organization.id })

    expect(data["errors"]).to be_empty
    expect(data["style"]).to include(
      "name" => "test_image.jpg",
      "kind" => "cover",
      "organizationId" => organization.id.to_s
    )

    style = Style.find(data.dig("style", "id"))
    expect(style.organization).to eq(organization)
    expect(style.image).to be_attached
  end

  it "resolves the asset's value to the attachment URL" do
    data = exec({ organizationId: organization.id })

    style = Style.find(data.dig("style", "id"))
    expect(data.dig("style", "value")).to eq(style.image_url)
    expect(data.dig("style", "value")).to be_present
  end

  # HasAttachedImage#image_url swaps in the CDN host when one is configured; an
  # org asset must be served from the same place as every other image.
  it "honors the CDN config in the asset's image_url" do
    allow(Rails.configuration.x).to receive_messages(cdn_enabled: true, cdn_host: "https://cdn.example.test")

    data = exec({ organizationId: organization.id })

    style = Style.find(data.dig("style", "id"))
    expect(data.dig("style", "value")).to eq("https://cdn.example.test/#{style.image.key}")
  end

  it "accepts an explicit name and kind" do
    data = exec({ organizationId: organization.id, name: "Acme Banner", kind: "effect" })

    expect(data["errors"]).to be_empty
    expect(data["style"]).to include("name" => "Acme Banner", "kind" => "effect")
  end

  it "returns validation errors for an unsupported kind" do
    data = exec({ organizationId: organization.id, kind: "sticker" })

    expect(data["style"]).to be_nil
    expect(data["errors"]).to include("Kind is not included in the list")
    expect(Style.where(organization:)).to be_empty
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = exec({ organizationId: organization.id }, user: member)

    expect(data["style"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(Style.where(organization:)).to be_empty
  end

  it "returns Not authorized for a non-member" do
    data = exec({ organizationId: organization.id }, user: create(:user))

    expect(data["style"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(Style.where(organization:)).to be_empty
  end

  it "returns a not-found error for an unknown organization" do
    data = exec({ organizationId: "0" })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: {
        operations: { query:, variables: { organizationId: organization.id, image: nil } }.to_json,
        map: { "0" => [ "variables.image" ] }.to_json,
        "0" => file
      }

    expect(response).to have_http_status(:unauthorized)
  end
end
