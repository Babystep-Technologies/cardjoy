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
end
