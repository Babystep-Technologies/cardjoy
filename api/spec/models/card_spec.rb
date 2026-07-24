require 'rails_helper'

RSpec.describe Card, type: :model do
  describe "kind" do
    it "defaults to group" do
      expect(create(:card).kind).to eq("group")
    end

    it "accepts the known kinds" do
      expect(build(:card, kind: "group")).to be_valid
      expect(build(:card, :one_on_one)).to be_valid
    end

    it "rejects a kind outside Card::KINDS" do
      card = build(:card, kind: "postcard")
      expect(card).not_to be_valid
      expect(card.errors[:kind]).to be_present
    end

    it "forces require_login_to_contribute to false for one_on_one cards" do
      card = create(:card, :one_on_one, require_login_to_contribute: true)
      expect(card.require_login_to_contribute).to be(false)
    end

    it "leaves require_login_to_contribute untouched for group cards" do
      card = create(:card, require_login_to_contribute: true)
      expect(card.require_login_to_contribute).to be(true)
    end
  end

  describe "contributor_prompt" do
    it "is optional" do
      expect(build(:card, contributor_prompt: nil)).to be_valid
      expect(build(:card, contributor_prompt: "")).to be_valid
    end

    it "accepts a prompt within the length limit" do
      expect(build(:card, contributor_prompt: "Share a favorite memory of working with Tom.")).to be_valid
    end

    it "rejects a prompt longer than 500 characters" do
      card = build(:card, contributor_prompt: "a" * 501)
      expect(card).not_to be_valid
      expect(card.errors[:contributor_prompt]).to be_present
    end
  end
end
