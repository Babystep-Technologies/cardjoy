require 'rails_helper'

RSpec.describe WishListReservation, type: :model do
  it "is valid with a guest name, email, and quantity" do
    expect(build(:wish_list_reservation)).to be_valid
  end

  it "requires a guest name" do
    reservation = build(:wish_list_reservation, guest_name: nil)
    expect(reservation).not_to be_valid
    expect(reservation.errors[:guest_name]).to be_present
  end

  it "requires a valid guest email" do
    expect(build(:wish_list_reservation, guest_email: nil)).not_to be_valid
    expect(build(:wish_list_reservation, guest_email: "not-an-email")).not_to be_valid
  end

  it "requires a positive quantity" do
    expect(build(:wish_list_reservation, quantity: 0)).not_to be_valid
  end

  it "downcases and strips the guest email" do
    reservation = create(:wish_list_reservation, guest_email: "  Alex@Example.com  ")
    expect(reservation.guest_email).to eq("alex@example.com")
  end

  it "generates a unique token on create" do
    reservation = create(:wish_list_reservation)
    expect(reservation.token).to be_present
    expect(create(:wish_list_reservation, wish_list_item: reservation.wish_list_item).token)
      .not_to eq(reservation.token)
  end
end
