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

  describe "archiving and guest email retention (#251, #252)" do
    it "archives once the event date has passed, never before or without a date" do
      expect(build(:wish_list, event_date: Date.current - 1)).to be_archived
      expect(build(:wish_list, event_date: Date.current)).not_to be_archived
      expect(build(:wish_list, event_date: nil)).not_to be_archived
    end

    it "is due for an email scrub a week after the event, not before" do
      due = create(:wish_list, :standalone, event_date: Date.current - 7)
      create(:wish_list, :standalone, event_date: Date.current - 6)
      create(:wish_list, :standalone, event_date: nil)

      expect(described_class.due_for_email_scrub).to contain_exactly(due)
    end
  end

  describe "insights with paused items (#310)" do
    it "leaves paused items out of the totals" do
      list = create(:wish_list, :standalone)
      create(:wish_list_item, wish_list: list)
      create(:wish_list_item, wish_list: list, paused: true)

      expect(list.insights).to include(item_count: 1)
    end
  end
end
