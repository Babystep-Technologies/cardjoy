require "rails_helper"

RSpec.describe Mutations::UpdateOrganization, type: :request do
  let(:admin) { create(:user) }
  let(:organization) { create(:organization, name: "Acme Corp", created_by: admin) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  before { create(:organization_membership, :admin, organization:, user: admin) }

  def headers_for(user)
    token = JWT.encode({ user_id: user.id }, secret, "HS256")
    { "Content-Type" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  let(:query) do
    <<~GRAPHQL
      mutation UpdateOrganization($organizationId: ID!, $name: String, $description: String) {
        updateOrganization(input: { organizationId: $organizationId, name: $name, description: $description }) {
          organization { id name slug description }
          errors
        }
      }
    GRAPHQL
  end

  def exec(variables, user: admin)
    post "/graphql", params: { query:, variables: }.to_json, headers: headers_for(user)
    JSON.parse(response.body).dig("data", "updateOrganization")
  end

  it "lets an admin rename the organization" do
    data = exec({ organizationId: organization.id, name: "Acme Incorporated" })

    expect(data["errors"]).to be_empty
    expect(data["organization"]).to include("name" => "Acme Incorporated")
    expect(organization.reload.name).to eq("Acme Incorporated")
  end

  it "keeps the slug stable across a rename" do
    data = exec({ organizationId: organization.id, name: "Acme Incorporated" })
    expect(data.dig("organization", "slug")).to eq("acme-corp")
  end

  it "updates the description on its own" do
    data = exec({ organizationId: organization.id, description: "Now with more cards" })

    expect(data["errors"]).to be_empty
    expect(data["organization"]).to include("name" => "Acme Corp", "description" => "Now with more cards")
  end

  it "returns Not authorized for a member who is not an admin" do
    member = create(:user)
    create(:organization_membership, organization:, user: member)

    data = exec({ organizationId: organization.id, name: "Hijacked" }, user: member)

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
    expect(organization.reload.name).to eq("Acme Corp")
  end

  it "returns Not authorized for a non-member" do
    data = exec({ organizationId: organization.id, name: "Hijacked" }, user: create(:user))

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to eq([ "Not authorized" ])
  end

  it "returns a not-found error for an unknown organization" do
    data = exec({ organizationId: "0", name: "Ghost" })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "returns a not-found error for an archived organization" do
    organization.archive!
    data = exec({ organizationId: organization.id, name: "Ghost" })
    expect(data["errors"]).to eq([ "Organization not found" ])
  end

  it "returns validation errors for a blank name" do
    data = exec({ organizationId: organization.id, name: "" })

    expect(data["organization"]).to be_nil
    expect(data["errors"]).to include("Name can't be blank")
  end

  it "rejects unauthenticated callers" do
    post "/graphql",
      params: { query:, variables: { organizationId: organization.id, name: "Ghost" } }.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end

  # Changing the slug is its own act, separate from a rename (#126).
  describe "slug" do
    let(:slug_query) do
      <<~GRAPHQL
        mutation UpdateOrganization($organizationId: ID!, $slug: String) {
          updateOrganization(input: { organizationId: $organizationId, slug: $slug }) {
            organization { id slug }
            errors
          }
        }
      GRAPHQL
    end

    def exec_slug(variables, user: admin)
      post "/graphql", params: { query: slug_query, variables: }.to_json, headers: headers_for(user)
      JSON.parse(response.body).dig("data", "updateOrganization")
    end

    it "lets an admin change the slug" do
      data = exec_slug({ organizationId: organization.id, slug: "acme-inc" })

      expect(data["errors"]).to be_empty
      expect(data.dig("organization", "slug")).to eq("acme-inc")
      expect(organization.reload.slug).to eq("acme-inc")
    end

    it "normalizes case and surrounding whitespace" do
      data = exec_slug({ organizationId: organization.id, slug: "  Acme-INC  " })

      expect(data["errors"]).to be_empty
      expect(organization.reload.slug).to eq("acme-inc")
    end

    it "rejects a slug with characters that don't belong in a URL" do
      data = exec_slug({ organizationId: organization.id, slug: "acme corp!" })

      expect(data["organization"]).to be_nil
      expect(data["errors"]).to eq([ Mutations::UpdateOrganization::SLUG_FORMAT_ERROR ])
      expect(organization.reload.slug).to eq("acme-corp")
    end

    it "rejects a blank slug" do
      data = exec_slug({ organizationId: organization.id, slug: "  " })

      expect(data["errors"]).to eq([ Mutations::UpdateOrganization::SLUG_BLANK_ERROR ])
      expect(organization.reload.slug).to eq("acme-corp")
    end

    it "rejects a slug that is too long" do
      data = exec_slug({ organizationId: organization.id, slug: "a" * (Organization::SLUG_MAX_LENGTH + 1) })

      expect(data["errors"]).to eq([ Mutations::UpdateOrganization::SLUG_LENGTH_ERROR ])
    end

    it "rejects a slug another organization already holds" do
      create(:organization, name: "Taken", slug: "taken", created_by: create(:user))

      data = exec_slug({ organizationId: organization.id, slug: "taken" })

      expect(data["errors"]).to eq([ Mutations::UpdateOrganization::SLUG_TAKEN_ERROR ])
      expect(organization.reload.slug).to eq("acme-corp")
    end

    it "rejects a slug an archived organization still holds" do
      create(:organization, name: "Gone", slug: "gone", created_by: create(:user)).archive!

      data = exec_slug({ organizationId: organization.id, slug: "gone" })

      expect(data["errors"]).to eq([ Mutations::UpdateOrganization::SLUG_TAKEN_ERROR ])
    end

    it "accepts the organization's own slug unchanged" do
      data = exec_slug({ organizationId: organization.id, slug: "acme-corp" })

      expect(data["errors"]).to be_empty
      expect(data.dig("organization", "slug")).to eq("acme-corp")
    end

    it "returns Not authorized for a member who is not an admin" do
      member = create(:user)
      create(:organization_membership, organization:, user: member)

      data = exec_slug({ organizationId: organization.id, slug: "hijacked" }, user: member)

      expect(data["errors"]).to eq([ "Not authorized" ])
      expect(organization.reload.slug).to eq("acme-corp")
    end
  end

  # Email branding (#123). The logo arrives as a multipart upload, so it is
  # exercised separately from the three scalar fields.
  describe "brand fields" do
    let(:brand_query) do
      <<~GRAPHQL
        mutation UpdateOrganization(
          $organizationId: ID!, $accentColor: String, $emailFooterText: String, $emailReplyTo: String
        ) {
          updateOrganization(input: {
            organizationId: $organizationId,
            accentColor: $accentColor,
            emailFooterText: $emailFooterText,
            emailReplyTo: $emailReplyTo
          }) {
            organization { id accentColor emailFooterText emailReplyTo logoUrl }
            errors
          }
        }
      GRAPHQL
    end

    def exec_brand(variables, user: admin)
      post "/graphql", params: { query: brand_query, variables: }.to_json, headers: headers_for(user)
      JSON.parse(response.body).dig("data", "updateOrganization")
    end

    it "lets an admin set the accent color, footer text, and reply-to" do
      data = exec_brand({
        organizationId: organization.id,
        accentColor: "#ff0055",
        emailFooterText: "© 2026 Acme Corp",
        emailReplyTo: "people@acme.example"
      })

      expect(data["errors"]).to be_empty
      expect(data["organization"]).to include(
        "accentColor" => "#ff0055",
        "emailFooterText" => "© 2026 Acme Corp",
        "emailReplyTo" => "people@acme.example"
      )
    end

    it "leaves omitted brand fields alone" do
      organization.update!(accent_color: "#ff0055")

      exec_brand({ organizationId: organization.id, emailReplyTo: "people@acme.example" })

      expect(organization.reload.accent_color).to eq("#ff0055")
    end

    it "clears a brand field back to the CardJoy default when passed an empty string" do
      organization.update!(accent_color: "#ff0055")

      data = exec_brand({ organizationId: organization.id, accentColor: "" })

      expect(data["errors"]).to be_empty
      expect(organization.reload.accent_color).to eq("")
    end

    it "rejects an accent color that isn't a hex value" do
      data = exec_brand({ organizationId: organization.id, accentColor: "red" })

      expect(data["organization"]).to be_nil
      expect(data["errors"]).to include("Accent color must be a hex color like #433c69")
      expect(organization.reload.accent_color).to be_nil
    end

    it "rejects a reply-to that isn't an email address" do
      data = exec_brand({ organizationId: organization.id, emailReplyTo: "nope" })

      expect(data["organization"]).to be_nil
      expect(data["errors"]).to be_present
    end

    it "returns Not authorized for a member who is not an admin" do
      member = create(:user)
      create(:organization_membership, organization:, user: member)

      data = exec_brand({ organizationId: organization.id, accentColor: "#ff0055" }, user: member)

      expect(data["errors"]).to eq([ "Not authorized" ])
      expect(organization.reload.accent_color).to be_nil
    end

    it "attaches an uploaded logo and exposes its URL" do
      file = fixture_file_upload("spec/fixtures/files/test_image.jpg", "image/jpeg")
      logo_query = <<~GRAPHQL
        mutation UpdateOrganization($organizationId: ID!, $logo: Upload) {
          updateOrganization(input: { organizationId: $organizationId, logo: $logo }) {
            organization { id logoUrl }
            errors
          }
        }
      GRAPHQL

      post "/graphql",
        params: {
          operations: { query: logo_query, variables: { organizationId: organization.id, logo: nil } }.to_json,
          map: { "0" => [ "variables.logo" ] }.to_json,
          "0" => file
        },
        headers: { "Authorization" => "Bearer #{JWT.encode({ user_id: admin.id }, secret, 'HS256')}" }

      data = JSON.parse(response.body).dig("data", "updateOrganization")

      expect(data["errors"]).to be_empty
      expect(data["organization"]["logoUrl"]).to be_present
      expect(organization.reload.logo).to be_attached
    end
  end
end
