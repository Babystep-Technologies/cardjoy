# spec/graphql/mutations/archive_cover_style_spec.rb
require 'rails_helper'
require 'jwt'

RSpec.describe Mutations::ArchiveCoverStyle, type: :request do
  let(:admin) { create(:admin) }
  let(:style) { create(:style, kind: "cover") }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) do
    JWT.encode({ admin_id: admin.id }, secret, 'HS256')
  end
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{token}"
    }
  end

  let(:query) do
    <<~GRAPHQL
      mutation ArchiveCoverStyle($id: ID!) {
        archiveCoverStyle(input: { id: $id }) {
          success
          errors
        }
      }
    GRAPHQL
  end

  def execute_mutation(id:, custom_headers: headers)
    post '/graphql',
      params: {
        query: query,
        variables: { id: id }
      }.to_json,
      headers: custom_headers
  end

  context "when admin is authenticated" do
    it "archives the style successfully" do
      expect(style.deleted_at).to be_nil

      execute_mutation(id: style.id)

      json = JSON.parse(response.body)
      data = json.dig("data", "archiveCoverStyle")

      expect(data["success"]).to eq(true)
      expect(data["errors"]).to be_empty
      expect(style.reload.deleted_at).not_to be_nil
    end

    it "returns error if style not found" do
      execute_mutation(id: "9999")

      json = JSON.parse(response.body)
      data = json.dig("data", "archiveCoverStyle")

      expect(data["success"]).to eq(false)
      expect(data["errors"]).to include("Style not found")
    end
  end

  context "when admin is not authenticated" do
    it "returns an unauthorized error" do
      execute_mutation(id: style.id, custom_headers: { 'Content-Type' => 'application/json' })

      json = JSON.parse(response.body)
      error = json["errors"].first["message"]

      expect(response.status).to eq(401)
      expect(error).to be_nil
    end
  end
end
