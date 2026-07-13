require 'rails_helper'

RSpec.describe Card, type: :model do
  describe "kind" do
    it "defaults to group" do
      card = build(:card)
      expect(card.kind).to eq("group")
    end

    it "is valid with kind 'group'" do
      card = build(:card, kind: "group")
      expect(card).to be_valid
    end

    it "is valid with kind 'one_on_one'" do
      card = build(:card, kind: "one_on_one")
      expect(card).to be_valid
    end

    it "is invalid with an unknown kind" do
      card = build(:card, kind: "invalid")
      expect(card).not_to be_valid
      expect(card.errors[:kind]).to be_present
    end

    it "forces require_login_to_contribute to false for one_on_one cards" do
      card = build(:card, :one_on_one, require_login_to_contribute: true)
      card.valid?
      expect(card.require_login_to_contribute).to be false
    end

    it "does not change require_login_to_contribute for group cards" do
      card = build(:card, kind: "group", require_login_to_contribute: true)
      card.valid?
      expect(card.require_login_to_contribute).to be true
    end
  end

  describe "#one_on_one?" do
    it "returns true for one_on_one cards" do
      card = build(:card, :one_on_one)
      expect(card.one_on_one?).to be true
    end

    it "returns false for group cards" do
      card = build(:card, kind: "group")
      expect(card.one_on_one?).to be false
    end
  end
end
