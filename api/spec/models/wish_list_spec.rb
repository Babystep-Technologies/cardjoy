require "rails_helper"

RSpec.describe WishList, type: :model do
  it "inherits its owner from the invitation it belongs to" do
    invitation = create(:invitation)

    list = described_class.create!(invitation: invitation, title: "Gifts")

    expect(list.user).to eq(invitation.user)
    expect(list).not_to be_standalone
  end

  it "can stand alone with its own owner" do
    list = create(:wish_list, :standalone)

    expect(list).to be_standalone
    expect(list.invitation).to be_nil
  end

  it "needs an owner" do
    expect(described_class.new(title: "x")).not_to be_valid
  end

  it "generates a unique public id" do
    ids = create_list(:wish_list, 3, :standalone).map(&:external_id)

    expect(ids.uniq.size).to eq(3)
    expect(ids).to all(match(/\A[a-z0-9]{10}\z/))
  end

  it "only accepts known occasions" do
    expect(build(:wish_list, :standalone, occasion: "birthday")).to be_valid
    expect(build(:wish_list, :standalone, occasion: nil)).to be_valid
    expect(build(:wish_list, :standalone, occasion: "nonsense")).not_to be_valid
  end

  it "recognizes its owner" do
    list = create(:wish_list, :standalone)

    expect(list.owned_by?(list.user)).to be true
    expect(list.owned_by?(create(:user))).to be false
    expect(list.owned_by?(nil)).to be false
  end

  it "is removed with its owner" do
    list = create(:wish_list, :standalone)

    expect { list.user.destroy! }.to change(described_class, :count).by(-1)
  end
end
