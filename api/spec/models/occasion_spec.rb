require "rails_helper"

RSpec.describe Occasion, type: :model do
  describe "validations" do
    it "requires kind, occurs_on and a known kind" do
      expect(build(:occasion, kind: nil)).not_to be_valid
      expect(build(:occasion, occurs_on: nil)).not_to be_valid
      expect(build(:occasion, kind: "Not A Real Occasion")).not_to be_valid
      expect(build(:occasion, kind: "Birthday")).to be_valid
    end
  end

  describe "#next_occurrence" do
    it "returns occurs_on unchanged for a non-recurring occasion" do
      occasion = build(:occasion, recurring: false, occurs_on: Date.new(2020, 1, 1))
      expect(occasion.next_occurrence).to eq(Date.new(2020, 1, 1))
    end

    it "rolls a recurring occasion forward to this year when still upcoming" do
      from = Date.new(2026, 1, 1)
      occasion = build(:occasion, recurring: true, occurs_on: Date.new(1990, 6, 15))
      expect(occasion.next_occurrence(from:)).to eq(Date.new(2026, 6, 15))
    end

    it "rolls a recurring occasion to next year once this year's date has passed" do
      from = Date.new(2026, 7, 1)
      occasion = build(:occasion, recurring: true, occurs_on: Date.new(1990, 6, 15))
      expect(occasion.next_occurrence(from:)).to eq(Date.new(2027, 6, 15))
    end

    it "clamps a Feb 29 recurring occasion to Feb 28 in a non-leap year" do
      from = Date.new(2025, 1, 1)
      occasion = build(:occasion, recurring: true, occurs_on: Date.new(2004, 2, 29))
      expect(occasion.next_occurrence(from:)).to eq(Date.new(2025, 2, 28))
    end
  end

  describe ".upcoming" do
    let(:user) { create(:user) }
    let(:contact) { create(:contact, user:) }

    it "includes only occasions whose next occurrence is within the window, soonest first" do
      soon = create(:occasion, contact:, recurring: true,
        occurs_on: Date.new(1990, (Date.current + 5.days).month, (Date.current + 5.days).day))
      later = create(:occasion, contact:, recurring: true,
        occurs_on: Date.new(1990, (Date.current + 20.days).month, (Date.current + 20.days).day))
      # Non-recurring occasion in the past is excluded.
      create(:occasion, contact:, recurring: false, occurs_on: Date.current - 10.days)

      result = described_class.upcoming(user:, within_days: 10)
      expect(result).to eq([ soon ])

      result = described_class.upcoming(user:, within_days: 30)
      expect(result).to eq([ soon, later ])
    end

    it "does not return another user's occasions" do
      create(:occasion, contact:, occurs_on: Date.current + 1.day, recurring: true)
      other_user = create(:user)
      expect(described_class.upcoming(user: other_user, within_days: 30)).to be_empty
    end
  end
end
