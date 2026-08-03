require 'rails_helper'

RSpec.describe WishList, type: :model do
  it "is valid with a title" do
    expect(build(:wish_list)).to be_valid
  end

  it "requires a title" do
    wish_list = build(:wish_list, title: nil)
    expect(wish_list).not_to be_valid
    expect(wish_list.errors[:title]).to be_present
  end

  it "returns items and contributions in position order" do
    wish_list = create(:wish_list)
    second = create(:wish_list_item, wish_list: wish_list, title: "Second", position: 1)
    first = create(:wish_list_item, wish_list: wish_list, title: "First", position: 0)

    expect(wish_list.reload.items).to eq([ first, second ])
  end

  it "is empty when it has no items or contributions" do
    wish_list = create(:wish_list)
    expect(wish_list).to be_empty

    create(:wish_list_item, wish_list: wish_list)
    expect(wish_list.reload).not_to be_empty
  end

  it "is destroyed along with its invitation" do
    wish_list = create(:wish_list)
    create(:wish_list_item, wish_list: wish_list)
    create(:wish_list_contribution, wish_list: wish_list)

    expect { wish_list.invitation.destroy }
      .to change(described_class, :count).by(-1)
      .and change(WishListItem, :count).by(-1)
      .and change(WishListContribution, :count).by(-1)
  end
end
