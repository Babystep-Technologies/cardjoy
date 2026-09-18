require 'rails_helper'

RSpec.describe WishListItem, type: :model do
  it "is valid with a title" do
    expect(build(:wish_list_item)).to be_valid
  end

  it "requires a title" do
    item = build(:wish_list_item, title: nil)
    expect(item).not_to be_valid
    expect(item.errors[:title]).to be_present
  end

  it "requires a positive quantity" do
    expect(build(:wish_list_item, quantity: 0)).not_to be_valid
    expect(build(:wish_list_item, quantity: 2)).to be_valid
  end

  it "allows a manual item with no url" do
    expect(build(:wish_list_item, url: nil)).to be_valid
  end

  it "rejects a url without a scheme" do
    item = build(:wish_list_item, url: "lovevery.com/play-gym")
    expect(item).not_to be_valid
    expect(item.errors[:url]).to be_present
  end

  it "derives the store from the url host" do
    item = create(:wish_list_item, url: "https://www.target.com/p/12345", store: nil)
    expect(item.store).to eq("target.com")
  end

  it "keeps a store the host set explicitly" do
    item = create(:wish_list_item, url: "https://www.target.com/p/12345", store: "Target")
    expect(item.store).to eq("Target")
  end

  it "leaves store blank for a manual item" do
    item = create(:wish_list_item, url: nil, store: nil)
    expect(item.store).to be_nil
  end

  describe "reservation claim state" do
    it "is unclaimed with no reservations" do
      item = create(:wish_list_item, quantity: 2)
      expect(item.reserved_quantity).to eq(0)
      expect(item.remaining_quantity).to eq(2)
      expect(item.claimed?).to be(false)
    end

    it "is claimed once reservations cover the full quantity" do
      item = create(:wish_list_item, quantity: 2)
      create(:wish_list_reservation, wish_list_item: item, quantity: 2)

      expect(item.reserved_quantity).to eq(2)
      expect(item.remaining_quantity).to eq(0)
      expect(item.claimed?).to be(true)
    end

    it "never reports negative remaining quantity" do
      item = create(:wish_list_item, quantity: 1)
      create(:wish_list_reservation, wish_list_item: item, quantity: 1)
      # A second reservation should never happen in practice (the mutation checks remaining
      # quantity first), but the display math must still degrade sanely if it ever did.
      create(:wish_list_reservation, wish_list_item: item, quantity: 1, guest_email: "other@example.com")

      expect(item.remaining_quantity).to eq(0)
    end

    it "destroys reservations when the item is destroyed" do
      item = create(:wish_list_item)
      create(:wish_list_reservation, wish_list_item: item)

      expect { item.destroy! }.to change(WishListReservation, :count).by(-1)
    end
  end
end
