require 'rails_helper'

RSpec.describe WishListContribution, type: :model do
  it "is valid with a supported kind and a handle" do
    expect(build(:wish_list_contribution)).to be_valid
  end

  it "rejects an unsupported kind" do
    contribution = build(:wish_list_contribution, kind: "bitcoin")
    expect(contribution).not_to be_valid
    expect(contribution.errors[:kind]).to be_present
  end

  it "requires a handle" do
    contribution = build(:wish_list_contribution, handle: "  ")
    expect(contribution).not_to be_valid
    expect(contribution.errors[:handle]).to be_present
  end

  describe "#action_url" do
    it "builds a Venmo link from a handle with or without the @" do
      expect(build(:wish_list_contribution, kind: "venmo", handle: "@host").action_url)
        .to eq("https://venmo.com/u/host")
      expect(build(:wish_list_contribution, kind: "venmo", handle: "host").action_url)
        .to eq("https://venmo.com/u/host")
    end

    it "builds a Cash App link from a cashtag" do
      expect(build(:wish_list_contribution, kind: "cashapp", handle: "$host").action_url)
        .to eq("https://cash.app/$host")
    end

    it "builds a PayPal link from a bare handle or a paypal.me path" do
      expect(build(:wish_list_contribution, kind: "paypal", handle: "host").action_url)
        .to eq("https://paypal.me/host")
      expect(build(:wish_list_contribution, kind: "paypal", handle: "paypal.me/host").action_url)
        .to eq("https://paypal.me/host")
    end

    it "passes through a handle that is already a url" do
      contribution = build(:wish_list_contribution, kind: "paypal", handle: "https://paypal.me/host")
      expect(contribution.action_url).to eq("https://paypal.me/host")
    end

    it "is nil for Zelle, which has no public deep link" do
      contribution = build(:wish_list_contribution, kind: "zelle", handle: "host@example.com")
      expect(contribution.action_url).to be_nil
      expect(contribution).not_to be_linkable
    end

    it "is nil for a Trump Account, which is funded through the custodian" do
      contribution = build(:wish_list_contribution, kind: "trump_account", handle: "Ask me for details")
      expect(contribution.action_url).to be_nil
      expect(contribution).not_to be_linkable
    end
  end
end
