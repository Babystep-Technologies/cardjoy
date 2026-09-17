require 'rails_helper'

RSpec.describe Mutations::ReleaseWishListReservation, type: :request do
  let(:item) { create(:wish_list_item, quantity: 1) }
  let(:reservation) { create(:wish_list_reservation, wish_list_item: item) }

  let(:query) do
    <<~GRAPHQL
      mutation ReleaseWishListReservation($token: String!) {
        releaseWishListReservation(input: { token: $token }) {
          wishListItem { id claimed remainingQuantity }
          errors
        }
      }
    GRAPHQL
  end

  def release(token)
    post "/graphql",
      params: { query: query, operationName: "ReleaseWishListReservation", variables: { token: token } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    parsed = JSON.parse(response.body)
    expect(parsed["errors"]).to be_nil, "unexpected GraphQL errors: #{parsed['errors'].inspect}"
    parsed.dig("data", "releaseWishListReservation")
  end

  it "releases the reservation and frees the item back up" do
    reservation # create it
    expect(item.reload.claimed?).to be(true)

    data = release(reservation.token)

    expect(data["errors"]).to be_empty
    expect(data["wishListItem"]["claimed"]).to be(false)
    expect(data["wishListItem"]["remainingQuantity"]).to eq(1)
    expect(WishListReservation.exists?(reservation.id)).to be(false)
  end

  it "returns an error for an unknown token" do
    data = release("does-not-exist")

    expect(data["wishListItem"]).to be_nil
    expect(data["errors"]).to eq([ "Reservation not found" ])
  end

  it "cannot be replayed once a reservation has been released" do
    token = reservation.token
    release(token)

    data = release(token)
    expect(data["errors"]).to eq([ "Reservation not found" ])
  end
end
