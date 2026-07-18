require "rails_helper"

RSpec.describe OccasionDesignSuggestion do
  describe ".for" do
    it "returns a curated suggestion for a known occasion kind" do
      suggestion = described_class.for("Birthday")
      expect(suggestion.headline).to be_present
      expect(suggestion.blurb).to be_present
    end

    it "covers every occasion kind with a valid effect slug or nil" do
      valid_effects = [ nil, "confetti", "sparkles", "hearts" ]
      Card::OCCASIONS.each do |kind|
        suggestion = described_class.for(kind)
        expect(suggestion.headline).to be_present, "expected a suggestion for #{kind}"
        expect(valid_effects).to include(suggestion.effect), "unexpected effect for #{kind}: #{suggestion.effect.inspect}"
      end
    end

    it "falls back to a default suggestion for an unknown kind" do
      expect(described_class.for("Something Novel")).to eq(described_class::DEFAULT)
      expect(described_class.for(nil)).to eq(described_class::DEFAULT)
    end
  end
end
