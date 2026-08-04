require 'rails_helper'

RSpec.describe "invitation.wishList", type: :request do
  let(:user) { create(:user) }
  let(:invitation) { create(:invitation, user: user) }
  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }

  let(:query) do
    <<~GRAPHQL
      query GetInvitation($externalId: String!) {
        invitation(externalId: $externalId) {
          wishList {
            title
            visible
            items { title }
            contributions { kind actionUrl }
          }
        }
      }
    GRAPHQL
  end

  def fetch(token: nil)
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{token}" if token

    post "/graphql",
      params: {
        query: query,
        operationName: "GetInvitation",
        variables: { externalId: invitation.external_id }
      }.to_json,
      headers: headers
    parsed = JSON.parse(response.body)
    expect(parsed["errors"]).to be_nil, "unexpected GraphQL errors: #{parsed['errors'].inspect}"
    parsed.dig("data", "invitation", "wishList")
  end

  it "is null when the invitation has no wish list" do
    expect(fetch).to be_nil
  end

  it "is visible to guests when the host published it" do
    wish_list = create(:wish_list, invitation: invitation, visible: true, title: "Baby shower")
    create(:wish_list_item, wish_list: wish_list, title: "Stroller")
    create(:wish_list_contribution, wish_list: wish_list, kind: "cashapp", handle: "$host")

    data = fetch
    expect(data["title"]).to eq("Baby shower")
    expect(data["items"].map { |i| i["title"] }).to eq([ "Stroller" ])
    expect(data["contributions"].first["actionUrl"]).to eq("https://cash.app/$host")
  end

  it "is hidden from guests when the host has not published it" do
    create(:wish_list, invitation: invitation, visible: false)
    expect(fetch).to be_nil
  end

  it "is hidden from a signed-in user who is not the host" do
    create(:wish_list, invitation: invitation, visible: false)
    other_token = JWT.encode({ user_id: create(:user).id }, secret, 'HS256')

    expect(fetch(token: other_token)).to be_nil
  end

  it "loads for a signed-out guest under the standalone wish list operation name" do
    create(:wish_list, invitation: invitation, visible: true, title: "Baby shower")

    post "/graphql",
      params: {
        query: query.sub("query GetInvitation(", "query GetInvitationWishList("),
        operationName: "GetInvitationWishList",
        variables: { externalId: invitation.external_id }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }

    parsed = JSON.parse(response.body)
    expect(parsed["errors"]).to be_nil
    expect(parsed.dig("data", "invitation", "wishList", "title")).to eq("Baby shower")
  end

  it "stays visible to the host so they can keep editing it" do
    create(:wish_list, invitation: invitation, visible: false, title: "Draft list")
    host_token = JWT.encode({ user_id: user.id }, secret, 'HS256')

    data = fetch(token: host_token)
    expect(data["title"]).to eq("Draft list")
    expect(data["visible"]).to be(false)
  end
end
