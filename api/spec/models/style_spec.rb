require 'rails_helper'

RSpec.describe Style, type: :model do
  describe "kind" do
    it "accepts the known kinds" do
      expect(build(:style, kind: "cover")).to be_valid
      expect(build(:style, kind: "background_color")).to be_valid
      expect(build(:style, kind: "text_color")).to be_valid
      expect(build(:style, :effect)).to be_valid
    end

    it "rejects an unknown kind" do
      style = build(:style, kind: "hologram")
      expect(style).not_to be_valid
      expect(style.errors[:kind]).to be_present
    end

    it "requires a kind" do
      style = build(:style, kind: nil)
      expect(style).not_to be_valid
      expect(style.errors[:kind]).to be_present
    end
  end

  describe ".effect" do
    it "returns only effect styles" do
      effect = create(:style, :effect)
      create(:style, kind: "cover")

      expect(Style.effect).to contain_exactly(effect)
    end
  end

  describe "#value" do
    it "falls back to source when no image is attached" do
      expect(create(:style, :effect, source: "confetti").value).to eq("confetti")
    end
  end
end
