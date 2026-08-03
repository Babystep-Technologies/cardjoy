require 'rails_helper'

RSpec.describe Mutations::UpsertWishList, type: :request do
  let(:user) { create(:user) }
  let(:invitation) { create(:invitation, user: user) }

  let(:secret) { Rails.application.credentials.dig(:jwt, :secret) }
  let(:token) { JWT.encode({ user_id: user.id }, secret, 'HS256') }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  let(:query) do
    <<~GRAPHQL
      mutation UpsertWishList(
        $invitationExternalId: String!
        $title: String
        $intro: String
        $visible: Boolean
        $surpriseMode: Boolean
        $items: [WishListItemInput!]
        $contributions: [WishListContributionInput!]
      ) {
        upsertWishList(
          input: {
            invitationExternalId: $invitationExternalId
            title: $title
            intro: $intro
            visible: $visible
            surpriseMode: $surpriseMode
            items: $items
            contributions: $contributions
          }
        ) {
          wishList {
            id
            title
            intro
            visible
            surpriseMode
            items { title url price note quantity position store }
            contributions { kind handle label suggestedAmount actionUrl position }
          }
          errors
        }
      }
    GRAPHQL
  end

  def upsert(variables, request_headers: headers)
    post "/graphql",
      params: { query: query, operationName: "UpsertWishList", variables: variables }.to_json,
      headers: request_headers
    JSON.parse(response.body).dig("data", "upsertWishList")
  end

  it "creates a wish list with items and contributions" do
    data = upsert({
      invitationExternalId: invitation.external_id,
      title: "Mia's 1st Birthday",
      intro: "No gift required!",
      items: [
        { title: "Play gym", url: "https://lovevery.com/play-gym", price: "$140", quantity: 1 },
        { title: "Books", note: "Board books please", quantity: 3 }
      ],
      contributions: [
        { kind: "venmo", handle: "@mia-mom", label: "Toward the crib" },
        { kind: "zelle", handle: "mom@example.com" }
      ]
    })

    expect(data["errors"]).to be_empty
    expect(data["wishList"]["title"]).to eq("Mia's 1st Birthday")
    expect(data["wishList"]["items"].map { |i| i["title"] }).to eq([ "Play gym", "Books" ])
    expect(data["wishList"]["items"].map { |i| i["position"] }).to eq([ 0, 1 ])
    expect(data["wishList"]["items"].first["store"]).to eq("lovevery.com")
    expect(data["wishList"]["contributions"].first["actionUrl"]).to eq("https://venmo.com/u/mia-mom")
    expect(data["wishList"]["contributions"].last["actionUrl"]).to be_nil

    expect(invitation.reload.wish_list.items.count).to eq(2)
  end

  it "replaces items and contributions on a second upsert" do
    upsert({
      invitationExternalId: invitation.external_id,
      items: [ { title: "Old item" } ],
      contributions: [ { kind: "venmo", handle: "@old" } ]
    })

    data = upsert({
      invitationExternalId: invitation.external_id,
      items: [ { title: "New item" } ],
      contributions: [ { kind: "cashapp", handle: "$new" } ]
    })

    expect(data["errors"]).to be_empty
    expect(data["wishList"]["items"].map { |i| i["title"] }).to eq([ "New item" ])
    expect(data["wishList"]["contributions"].map { |c| c["handle"] }).to eq([ "$new" ])
    expect(WishListItem.count).to eq(1)
    expect(WishListContribution.count).to eq(1)
  end

  it "leaves existing items alone when the argument is omitted" do
    upsert({ invitationExternalId: invitation.external_id, items: [ { title: "Keep me" } ] })

    data = upsert({ invitationExternalId: invitation.external_id, title: "Renamed" })

    expect(data["wishList"]["title"]).to eq("Renamed")
    expect(data["wishList"]["items"].map { |i| i["title"] }).to eq([ "Keep me" ])
  end

  it "rejects an unsupported contribution kind" do
    data = upsert({
      invitationExternalId: invitation.external_id,
      contributions: [ { kind: "bitcoin", handle: "abc" } ]
    })

    expect(data["wishList"]).to be_nil
    expect(data["errors"].first).to include("Unsupported contribution type")
  end

  it "surfaces validation errors and rolls back" do
    data = upsert({
      invitationExternalId: invitation.external_id,
      items: [ { title: "Fine" }, { title: "" } ]
    })

    expect(data["wishList"]).to be_nil
    expect(data["errors"].join).to include("Title")
    expect(WishListItem.count).to eq(0)
  end

  it "is rejected by the controller auth gate when signed out" do
    upsert(
      { invitationExternalId: invitation.external_id },
      request_headers: { 'Content-Type' => 'application/json' }
    )

    # UpsertWishList is not in GraphqlController::PUBLIC_OPERATIONS, so the request never
    # reaches the resolver.
    expect(JSON.parse(response.body)["errors"]).to eq([ "Unauthorized" ])
    expect(WishList.count).to eq(0)
  end

  it "does not let another user edit the wish list" do
    other_token = JWT.encode({ user_id: create(:user).id }, secret, 'HS256')

    data = upsert(
      { invitationExternalId: invitation.external_id, title: "Hijacked" },
      request_headers: { 'Authorization' => "Bearer #{other_token}", 'Content-Type' => 'application/json' }
    )

    expect(data["wishList"]).to be_nil
    expect(data["errors"]).to eq([ "Invitation not found" ])
  end
end
