require 'rails_helper'

RSpec.describe Mutations::PreviewWishListLink, type: :request do
  let(:user) { create(:user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  let(:query) do
    <<~GRAPHQL
      mutation PreviewWishListLink($url: String!) {
        previewWishListLink(input: { url: $url }) {
          preview { title imageUrl price store }
          errors
        }
      }
    GRAPHQL
  end

  def preview(url, request_headers: headers)
    post "/graphql",
      params: { query: query, operationName: "PreviewWishListLink", variables: { url: url } }.to_json,
      headers: request_headers
    JSON.parse(response.body).dig("data", "previewWishListLink")
  end

  it "returns a preview built from the fetched page" do
    allow(WishListLinkPreview).to receive(:fetch).with("https://store.example.com/product").and_return(
      WishListLinkPreview::Result.new(title: "Play Gym", image_url: "https://store.example.com/i.jpg", price: "$140", store: "Lovevery")
    )

    data = preview("https://store.example.com/product")

    expect(data["errors"]).to be_empty
    expect(data["preview"]).to eq(
      "title" => "Play Gym", "imageUrl" => "https://store.example.com/i.jpg", "price" => "$140", "store" => "Lovevery"
    )
  end

  it "returns a friendly error when no preview could be built" do
    allow(WishListLinkPreview).to receive(:fetch).and_return(nil)

    data = preview("https://store.example.com/unknown")

    expect(data["preview"]).to be_nil
    expect(data["errors"]).to eq([ "Couldn't find a preview for that link" ])
  end

  it "is rejected by the controller auth gate when signed out" do
    preview("https://store.example.com/product", request_headers: { 'Content-Type' => 'application/json' })

    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
  end
end
