require 'rails_helper'

RSpec.describe Mutations::ReserveWishListItem, type: :request do
  let(:wish_list) { create(:wish_list) }
  let(:item) { create(:wish_list_item, wish_list: wish_list, quantity: 2) }

  let(:query) do
    <<~GRAPHQL
      mutation ReserveWishListItem(
        $wishListItemId: ID!
        $guestName: String!
        $guestEmail: String!
        $quantity: Int
        $passcode: String
        $alreadyPurchased: Boolean
      ) {
        reserveWishListItem(
          input: {
            wishListItemId: $wishListItemId
            guestName: $guestName
            guestEmail: $guestEmail
            quantity: $quantity
            passcode: $passcode
            alreadyPurchased: $alreadyPurchased
          }
        ) {
          token
          reservation { id guestName quantity }
          wishListItem { id claimed remainingQuantity reservedQuantity }
          errors
        }
      }
    GRAPHQL
  end

  def reserve(variables)
    post "/graphql",
      params: { query: query, operationName: "ReserveWishListItem", variables: variables }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    parsed = JSON.parse(response.body)
    expect(parsed["errors"]).to be_nil, "unexpected GraphQL errors: #{parsed['errors'].inspect}"
    parsed.dig("data", "reserveWishListItem")
  end

  it "can claim an item the guest has already bought, so it is born purchased and never goes stale" do
    result = reserve(wishListItemId: item.id.to_s, guestName: "Pat", guestEmail: "pat@example.com", alreadyPurchased: true)

    expect(result["errors"]).to be_empty
    claim = item.reservations.last
    expect(claim).to be_purchased
    expect(WishListReservation.due_for_reminder).not_to include(claim)
    expect(WishListReservation.due_for_release).not_to include(claim)
  end

  it "leaves an ordinary claim unpurchased" do
    reserve(wishListItemId: item.id.to_s, guestName: "Pat", guestEmail: "pat@example.com")

    expect(item.reservations.last).not_to be_purchased
  end

  it "refuses a claim on a passcode-protected registry without the passcode" do
    wish_list.update!(passcode: "sunflower")
    vars = { wishListItemId: item.id.to_s, guestName: "Pat", guestEmail: "pat@example.com" }

    expect(reserve(vars)["errors"].join).to include("passcode")
    expect(item.reservations).to be_empty

    expect(reserve(vars.merge(passcode: "sunflower"))["errors"]).to be_empty
    expect(item.reservations.count).to eq(1)
  end

  it "refuses a claim once the registry's event has passed" do
    wish_list.update!(event_date: Date.current - 1)

    result = reserve(wishListItemId: item.id.to_s, guestName: "Late", guestEmail: "late@example.com")

    expect(result["errors"].join).to include("event has passed")
    expect(item.reservations).to be_empty
  end

  it "reserves an item for a signed-out guest and returns a token" do
    data = reserve({
      wishListItemId: item.id.to_s,
      guestName: "Jamie Guest",
      guestEmail: "jamie@example.com",
      quantity: 1
    })

    expect(data["errors"]).to be_empty
    expect(data["token"]).to be_present
    expect(data["reservation"]["guestName"]).to eq("Jamie Guest")
    expect(data["wishListItem"]["remainingQuantity"]).to eq(1)
    expect(data["wishListItem"]["claimed"]).to be(false)
  end

  it "emails the guest a confirmation with a link to manage their claim" do
    expect {
      reserve({ wishListItemId: item.id.to_s, guestName: "Jamie Guest", guestEmail: "jamie@example.com" })
    }.to have_enqueued_mail(WishListMailer, :claim_confirmation)
  end

  it "sends nothing when the claim is refused" do
    expect {
      reserve({ wishListItemId: "0", guestName: "Jamie Guest", guestEmail: "jamie@example.com" })
    }.not_to have_enqueued_mail(WishListMailer, :claim_confirmation)
  end

  it "marks the item claimed once quantity is fully reserved" do
    data = reserve({
      wishListItemId: item.id.to_s,
      guestName: "Jamie Guest",
      guestEmail: "jamie@example.com",
      quantity: 2
    })

    expect(data["wishListItem"]["claimed"]).to be(true)
    expect(data["wishListItem"]["remainingQuantity"]).to eq(0)
  end

  it "rejects a reservation that exceeds the remaining quantity" do
    create(:wish_list_reservation, wish_list_item: item, quantity: 2)

    data = reserve({
      wishListItemId: item.id.to_s,
      guestName: "Late Guest",
      guestEmail: "late@example.com",
      quantity: 1
    })

    expect(data["reservation"]).to be_nil
    expect(data["errors"]).to eq([ "This item is already fully claimed" ])
    expect(WishListReservation.count).to eq(1)
  end

  it "returns a not-found error for an unknown item" do
    data = reserve({
      wishListItemId: "999999",
      guestName: "Jamie Guest",
      guestEmail: "jamie@example.com",
      quantity: 1
    })

    expect(data["errors"]).to eq([ "Item not found" ])
  end

  it "surfaces validation errors for a malformed guest email" do
    data = reserve({
      wishListItemId: item.id.to_s,
      guestName: "Jamie Guest",
      guestEmail: "not-an-email",
      quantity: 1
    })

    expect(data["reservation"]).to be_nil
    expect(data["errors"].join).to include("Guest email")
  end
end
