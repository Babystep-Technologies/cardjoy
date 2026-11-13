require "rails_helper"

RSpec.describe Mutations::SetWishListReservationPurchased, type: :request do
  let(:item) { create(:wish_list_item, quantity: 1) }
  let(:reservation) { create(:wish_list_reservation, wish_list_item: item) }

  let(:query) do
    <<~GRAPHQL
      mutation SetWishListReservationPurchased($token: String!, $purchased: Boolean) {
        setWishListReservationPurchased(input: { token: $token, purchased: $purchased }) {
          wishListItem { id claimed }
          errors
        }
      }
    GRAPHQL
  end

  def run(variables)
    post "/graphql",
      params: { query: query, operationName: "SetWishListReservationPurchased", variables: variables }.to_json,
      headers: { "Content-Type" => "application/json" }
    JSON.parse(response.body).dig("data", "setWishListReservationPurchased")
  end

  it "marks a claim as purchased without needing an account" do
    data = run({ token: reservation.token })

    expect(data["errors"]).to be_empty
    expect(data["wishListItem"]["claimed"]).to be(true)
    expect(reservation.reload).to be_purchased
  end

  it "keeps the original purchase time when marked twice" do
    run({ token: reservation.token })
    first = reservation.reload.purchased_at

    run({ token: reservation.token })

    expect(reservation.reload.purchased_at).to eq(first)
  end

  it "takes a purchase back" do
    reservation.update!(purchased_at: 1.day.ago)

    run({ token: reservation.token, purchased: false })

    expect(reservation.reload).not_to be_purchased
  end

  it "restarts the reminder clock when a purchase is taken back" do
    reservation.update!(purchased_at: 1.day.ago, reminded_at: 10.days.ago)

    run({ token: reservation.token, purchased: false })

    expect(reservation.reload.reminded_at).to be_nil
    expect(WishListReservation.due_for_release).not_to include(reservation)
  end

  it "reports an unknown token" do
    expect(run({ token: "nope" })["errors"]).to eq([ "Reservation not found" ])
  end

  it "scopes purchased and unpurchased claims" do
    bought = create(:wish_list_reservation, wish_list_item: item, purchased_at: Time.current)

    expect(WishListReservation.purchased).to contain_exactly(bought)
    expect(WishListReservation.unpurchased).not_to include(bought)
  end
end
